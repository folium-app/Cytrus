// Copyright 2024 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#ifdef ENABLE_PROFILING
#include <tracy/Tracy.hpp>
#include "common/scope_exit.h"

#define MANDARINE_PROFILE(scope, text)                                                             \
    ZoneScopedN(text);                                                                             \
    ZoneText(scope, std::string::traits_type::length(scope));

#define MANDARINE_SCOPED_FRAME(text)                                                               \
    constexpr const char* CONCAT2(FrameTitle, __LINE__) = text;                                    \
    detail::ScopeHelper([&]() { FrameMarkStart(CONCAT2(FrameTitle, __LINE__)); },                  \
                        [&]() { FrameMarkEnd(CONCAT2(FrameTitle, __LINE__)); })

#define MANDARINE_FRAME_BEGIN(text) FrameMarkStart(text)

#define MANDARINE_FRAME_END(text) FrameMarkEnd(text)
#else

#define MANDARINE_PROFILE(scope, text)
#define MANDARINE_SCOPED_FRAME(text)
#define MANDARINE_FRAME_BEGIN(text)
#define MANDARINE_FRAME_END(text)

#endif
