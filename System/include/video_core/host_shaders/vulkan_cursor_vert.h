// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_CURSOR_VERT = {
"// Copyright Citra Emulator Project / Azahar Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"#extension GL_ARB_separate_shader_objects : enable\n"
"\n"
"layout (location = 0) in vec2 vert_position;\n"
"\n"
"void main() {\n"
"    gl_Position = vec4(vert_position, 0.0, 1.0);\n"
"}\n"
"\n"

};

} // namespace HostShaders
