// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_PRESENT_VERT = {
"// Copyright 2022 Citra Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"#extension GL_ARB_separate_shader_objects : enable\n"
"\n"
"layout (location = 0) in vec2 vert_position;\n"
"layout (location = 1) in vec2 vert_tex_coord;\n"
"layout (location = 0) out vec2 frag_tex_coord;\n"
"\n"
"layout (push_constant, std140) uniform DrawInfo {\n"
"    mat4 modelview_matrix;\n"
"    vec4 i_resolution;\n"
"    vec4 o_resolution;\n"
"    int screen_id_l;\n"
"    int screen_id_r;\n"
"    int layer;\n"
"};\n"
"\n"
"void main() {\n"
"    vec4 position = vec4(vert_position, 0.0, 1.0) * modelview_matrix;\n"
"    gl_Position = vec4(position.x, position.y, 0.0, 1.0);\n"
"    frag_tex_coord = vert_tex_coord;\n"
"}\n"
"\n"

};

} // namespace HostShaders
