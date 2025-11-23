// Copyright 2018 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include "input_common/sdl/sdl.h"
#include "input_common/sdl/sdl_impl.h"

namespace InputCommon::SDL {

std::unique_ptr<State> Init() {
    return std::make_unique<SDLState>();
}
} // namespace InputCommon::SDL
