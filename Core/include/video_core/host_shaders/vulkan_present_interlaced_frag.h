// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {
// clang-format off
constexpr std::string_view VULKAN_PRESENT_INTERLACED_FRAG = {
"// Copyright 2022 Citra Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"#extension GL_ARB_separate_shader_objects : enable\n"
"\n"
"layout (location = 0) in vec2 frag_tex_coord;\n"
"layout (location = 0) out vec4 color;\n"
"\n"
"layout (push_constant, std140) uniform DrawInfo {\n"
"    mat4 modelview_matrix;\n"
"    vec4 i_resolution;\n"
"    vec4 o_resolution;\n"
"    int screen_id_l;\n"
"    int screen_id_r;\n"
"    int layer;\n"
"    int reverse_interlaced;\n"
"};\n"
"\n"
"layout (set = 0, binding = 0) uniform sampler2D screen_textures[3];\n"
"\n"
"void main() {\n"
"    float screen_row = o_resolution.x * frag_tex_coord.x;\n"
"    if (int(screen_row) % 2 == reverse_interlaced)\n"
"        color = texture(screen_textures[screen_id_l], frag_tex_coord);\n"
"    else\n"
"        color = texture(screen_textures[screen_id_r], frag_tex_coord);\n"
"}\n"
"\n"

    // clang-format on
};

} // namespace HostShaders
