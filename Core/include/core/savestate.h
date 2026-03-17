// Copyright 2020 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#if __APPLE__
#import <TargetConditionals.h>
#endif

#include <string>
#include <vector>
#include "common/common_types.h"

namespace Core {

struct SaveStateInfo {
    u32 slot;
    u64 time;
    enum class ValidationStatus {
        OK,
        RevisionDismatch,
    } status;
    std::string build_name;
};

constexpr u32 SaveStateSlotCount = 11; // Maximum count of savestate slots

#if TARGET_OS_IOS
std::string GetSaveStatePath(u64 program_id, u64 movie_id, u32 slot);
std::vector<std::pair<SaveStateInfo, std::optional<std::string>>> ListSaveStates(u64 program_id,
                                                                                 u64 movie_id);
#else
std::vector<SaveStateInfo> ListSaveStates(u64 program_id, u64 movie_id);
#endif

} // namespace Core
