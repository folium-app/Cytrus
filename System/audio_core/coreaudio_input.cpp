// Copyright Citra Emulator Project / Azahar Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <utility>
#include <vector>
#include "audio_core/input.h"
#include "audio_core/coreaudio_input.h"
#include "audio_core/sink.h"
#include "common/logging/log.h"

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <mutex>
#include <deque>

namespace AudioCore {

struct CoreAudioInput::Impl {
    AudioQueueRef queue = nullptr;
    AudioStreamBasicDescription format{};

    std::mutex mutex;
    std::deque<u8> captured;

    std::vector<AudioQueueBufferRef> buffers;

    u8 sample_size_in_bytes = 0;
};

CoreAudioInput::CoreAudioInput(std::string device_id)
    : impl(std::make_unique<Impl>()), device_id(std::move(device_id)) {}

CoreAudioInput::~CoreAudioInput() {
    StopSampling();
}

static void InputCallback(
    void* user_data,
    AudioQueueRef queue,
    AudioQueueBufferRef buffer,
    const AudioTimeStamp*,
    UInt32,
    const AudioStreamPacketDescription*) {
    if (buffer->mAudioDataByteSize == 0) {
        AudioQueueEnqueueBuffer(queue, buffer, 0, nullptr);
        return;
    }

    auto* impl = static_cast<CoreAudioInput::Impl*>(user_data);

    {
        std::lock_guard lock(impl->mutex);

        auto* begin = static_cast<u8*>(buffer->mAudioData);
        impl->captured.insert(
            impl->captured.end(),
            begin,
            begin + buffer->mAudioDataByteSize);
        
        constexpr size_t MaxBufferedBytes = 65536;

        while (impl->captured.size() > MaxBufferedBytes)
            impl->captured.pop_front();
    }

    AudioQueueEnqueueBuffer(queue, buffer, 0, nullptr);
}

void CoreAudioInput::StartSampling(const InputParameters& params) {
    if (IsSampling())
        return;

    parameters = params;
    impl->sample_size_in_bytes = params.sample_size / 8;

    memset(&impl->format, 0, sizeof(impl->format));

    impl->format.mSampleRate = params.sample_rate;
    impl->format.mFormatID = kAudioFormatLinearPCM;
    impl->format.mChannelsPerFrame = 1;
    impl->format.mFramesPerPacket = 1;
    impl->format.mBitsPerChannel = params.sample_size;
    impl->format.mBytesPerFrame = impl->sample_size_in_bytes;
    impl->format.mBytesPerPacket = impl->sample_size_in_bytes;

    impl->format.mFormatFlags = kLinearPCMFormatFlagIsPacked;

    if (params.sample_size == 16)
        impl->format.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;

    auto status = AudioQueueNewInput(
        &impl->format,
        InputCallback,
        impl.get(),
        nullptr,
        nullptr,
        0,
        &impl->queue);

    if (status != noErr) {
        LOG_CRITICAL(Audio, "AudioQueueNewInput failed: {}", status);
        return;
    }
    
    UInt32 size = sizeof(impl->format);

    AudioQueueGetProperty(
        impl->queue,
        kAudioQueueProperty_StreamDescription,
        &impl->format,
        &size);

    LOG_INFO(Audio,
             "{} Hz {} bits",
             impl->format.mSampleRate,
             impl->format.mBitsPerChannel);

    constexpr int BufferCount = 3;

    for (int i = 0; i < BufferCount; i++) {
        AudioQueueBufferRef buffer;

        OSStatus status = AudioQueueAllocateBuffer(
            impl->queue,
            static_cast<UInt32>(params.buffer_size),
            &buffer);

        if (status != noErr) {
            LOG_CRITICAL(Audio, "AudioQueueAllocateBuffer failed: {}", status);
            StopSampling();
            return;
        }

        buffer->mAudioDataByteSize = static_cast<UInt32>(params.buffer_size);

        status = AudioQueueEnqueueBuffer(
            impl->queue,
            buffer,
            0,
            nullptr);

        if (status != noErr) {
            LOG_CRITICAL(Audio, "AudioQueueEnqueueBuffer failed: {}", status);
            StopSampling();
            return;
        }

        impl->buffers.push_back(buffer);
    }

    status = AudioQueueStart(impl->queue, nullptr);

    if (status != noErr) {
        LOG_CRITICAL(Audio, "AudioQueueStart failed: {}", status);
        StopSampling();
    }
}

void CoreAudioInput::StopSampling() {
    if (!impl->queue)
        return;

    AudioQueueStop(impl->queue, true);
    AudioQueueDispose(impl->queue, true);
    impl->queue = nullptr;

    std::lock_guard lock(impl->mutex);
    impl->captured.clear();
}

bool CoreAudioInput::IsSampling() {
    return impl->queue != nullptr;
}

void CoreAudioInput::AdjustSampleRate(u32 sample_rate) {
    if (!IsSampling())
        return;

    auto new_params = parameters;
    new_params.sample_rate = sample_rate;

    StopSampling();
    StartSampling(new_params);
}

Samples CoreAudioInput::Read() {
    if (!IsSampling())
        return {};

    std::lock_guard lock(impl->mutex);

    size_t available = impl->captured.size();

    size_t wanted = std::min(
        available,
        static_cast<size_t>(parameters.buffer_size));

    wanted -= wanted % impl->sample_size_in_bytes;

    Samples samples(wanted);

    std::copy_n(
        impl->captured.begin(),
        wanted,
        samples.begin());

    impl->captured.erase(
        impl->captured.begin(),
        impl->captured.begin() + wanted);

    return samples;
}

std::vector<std::string> ListCoreAudioInputDevices() {
    return { "Default" };
}

} // namespace AudioCore
