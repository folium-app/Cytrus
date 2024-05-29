// Copyright 2019 yuzu Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <algorithm>
#include <limits>
#include "common/alignment.h"
#include "common/assert.h"
#include "video_core/renderer_vulkan/vk_instance.h"
#include "video_core/renderer_vulkan/vk_memory_util.h"
#include "video_core/renderer_vulkan/vk_scheduler.h"
#include "video_core/renderer_vulkan/vk_stream_buffer.h"

namespace Vulkan {

namespace {

std::string_view BufferTypeName(BufferType type) {
    switch (type) {
    case BufferType::Upload:
        return "Upload";
    case BufferType::Download:
        return "Download";
    case BufferType::Stream:
        return "Stream";
    default:
        return "Invalid";
    }
}

vk::MemoryPropertyFlags MakePropertyFlags(BufferType type) {
    switch (type) {
    case BufferType::Upload:
        return vk::MemoryPropertyFlagBits::eHostVisible | vk::MemoryPropertyFlagBits::eHostCoherent;
    case BufferType::Download:
        return vk::MemoryPropertyFlagBits::eHostVisible |
               vk::MemoryPropertyFlagBits::eHostCoherent | vk::MemoryPropertyFlagBits::eHostCached;
    case BufferType::Stream:
        return vk::MemoryPropertyFlagBits::eDeviceLocal | vk::MemoryPropertyFlagBits::eHostVisible |
               vk::MemoryPropertyFlagBits::eHostCoherent;
    default:
        UNREACHABLE_MSG("Unknown buffer type {}", type);
        return vk::MemoryPropertyFlagBits::eHostVisible;
    }
}

/// Get the preferred host visible memory type.
u32 GetMemoryType(const vk::PhysicalDeviceMemoryProperties& properties, BufferType type) {
    vk::MemoryPropertyFlags flags = MakePropertyFlags(type);
    std::optional preferred_type = FindMemoryType(properties, flags);

    constexpr std::array remove_flags = {
        vk::MemoryPropertyFlagBits::eHostCached,
        vk::MemoryPropertyFlagBits::eHostCoherent,
    };

    for (u32 i = 0; i < remove_flags.size() && !preferred_type; i++) {
        flags &= ~remove_flags[i];
        preferred_type = FindMemoryType(properties, flags);
    }
    ASSERT_MSG(preferred_type, "No suitable memory type found");
    return preferred_type.value();
}

constexpr u64 WATCHES_INITIAL_RESERVE = 0x4000;
constexpr u64 WATCHES_RESERVE_CHUNK = 0x1000;

} // Anonymous namespace

StreamBuffer::StreamBuffer(const Instance& instance_, Scheduler& scheduler_,
                           vk::BufferUsageFlags usage_, u64 size, BufferType type_)
    : instance{instance_}, scheduler{scheduler_}, device{instance.GetDevice()},
      stream_buffer_size{size}, usage{usage_}, type{type_} {
    CreateBuffers(size);
    ReserveWatches(current_watches, WATCHES_INITIAL_RESERVE);
    ReserveWatches(previous_watches, WATCHES_INITIAL_RESERVE);
}

StreamBuffer::~StreamBuffer() {
    device.unmapMemory(memory);
    device.destroyBuffer(buffer);
    device.freeMemory(memory);
}

std::tuple<u8*, u32, bool> StreamBuffer::Map(u32 size, u64 alignment) {
    if (!is_coherent && type == BufferType::Stream) {
        size = Common::AlignUp(size, instance.NonCoherentAtomSize());
    }

    ASSERT(size <= stream_buffer_size);
    mapped_size = size;

    if (alignment > 0) {
        offset = Common::AlignUp(offset, alignment);
    }

    bool invalidate{false};
    if (offset + size > stream_buffer_size) {
        // The buffer would overflow, save the amount of used watches and reset the state.
        invalidate = true;
        invalidation_mark = current_watch_cursor;
        current_watch_cursor = 0;
        offset = 0;

        // Swap watches and reset waiting cursors.
        std::swap(previous_watches, current_watches);
        wait_cursor = 0;
        wait_bound = 0;
    }

    const u64 mapped_upper_bound = offset + size;
    WaitPendingOperations(mapped_upper_bound);

    return std::make_tuple(mapped + offset, offset, invalidate);
}

void StreamBuffer::Commit(u32 size) {
    if (!is_coherent && type == BufferType::Stream) {
        size = Common::AlignUp(size, instance.NonCoherentAtomSize());
    }

    ASSERT_MSG(size <= mapped_size, "Reserved size {} is too small compared to {}", mapped_size,
               size);

    const vk::MappedMemoryRange range = {
        .memory = memory,
        .offset = offset,
        .size = size,
    };

    if (!is_coherent && type == BufferType::Download) {
        device.invalidateMappedMemoryRanges(range);
    } else if (!is_coherent) {
        device.flushMappedMemoryRanges(range);
    }

    offset += size;

    if (current_watch_cursor + 1 >= current_watches.size()) {
        // Ensure that there are enough watches.
        ReserveWatches(current_watches, WATCHES_RESERVE_CHUNK);
    }
    auto& watch = current_watches[current_watch_cursor++];
    watch.upper_bound = offset;
    watch.tick = scheduler.CurrentTick();
}

void StreamBuffer::CreateBuffers(u64 prefered_size) {
    if (!memory || stream_buffer_size < prefered_size) {
        if (memory) {
            // reuse existing memory allocation
            device.unmapMemory(memory);
            device.destroyBuffer(buffer);
            device.freeMemory(memory);
        }
        AllocateMemory(prefered_size);
    } else {
        // reuse existing memory allocation
        device.unmapMemory(memory);
    }
    // reuse existing buffer
    if (!buffer) {
        device.destroyBuffer(buffer);
    }
    buffer = device.createBuffer({
        .size = prefered_size,
        .usage = usage,
    });
    device.bindBufferMemory(buffer, memory, 0);
    mapped = reinterpret_cast<u8*>(device.mapMemory(memory, 0, VK_WHOLE_SIZE));
}

void StreamBuffer::ReserveWatches(std::vector<Watch>& watches, std::size_t grow_size) {
    watches.resize(watches.size() + grow_size);
}

void StreamBuffer::WaitPendingOperations(u64 requested_upper_bound) {
    if (!invalidation_mark) {
        return;
    }
    while (requested_upper_bound > wait_bound && wait_cursor < *invalidation_mark) {
        auto& watch = previous_watches[wait_cursor];
        wait_bound = watch.upper_bound;
        scheduler.Wait(watch.tick);
        ++wait_cursor;
    }
}

void StreamBuffer::AllocateMemory(u64 prefered_size) {
    const vk::Device device = instance.GetDevice();
    const auto memory_properties = instance.GetPhysicalDevice().getMemoryProperties();
    const u32 preferred_type = GetMemoryType(memory_properties, type);
    const vk::MemoryType mem_type = memory_properties.memoryTypes[preferred_type];
    const u32 preferred_heap = mem_type.heapIndex;
    is_coherent =
        static_cast<bool>(mem_type.propertyFlags & vk::MemoryPropertyFlagBits::eHostCoherent);

    // Subtract from the preferred heap size some bytes to avoid getting out of memory.
    const vk::DeviceSize heap_size = memory_properties.memoryHeaps[preferred_heap].size;
    // As per DXVK's example, using `heap_size / 2`
    const vk::DeviceSize allocable_size = heap_size / 2;
    if (prefered_size > allocable_size) {
        LOG_ERROR(Render_Vulkan, "Requested buffer size exceeds allocable memory size");
        return;
    }

    memory = device.allocateMemory({
        .allocationSize = prefered_size,
        .memoryTypeIndex = preferred_type,
    });
    mapped = reinterpret_cast<u8*>(device.mapMemory(memory, 0, VK_WHOLE_SIZE));

    if (instance.HasDebuggingToolAttached()) {
        SetObjectName(device, memory, "StreamBufferMemory({}): {} Kib {}", BufferTypeName(type),
                      prefered_size / 1024, vk::to_string(mem_type.propertyFlags));
    }
}

} // namespace Vulkan
