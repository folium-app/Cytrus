// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_PRESENT_FRAG = {
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
"vec4 GetScreen(int screen_id) {\n"
"#ifdef ARRAY_DYNAMIC_INDEX\n"
"    return texture(screen_textures[screen_id], frag_tex_coord);\n"
"#else\n"
"    switch (screen_id) {\n"
"    case 0:\n"
"        return texture(screen_textures[0], frag_tex_coord);\n"
"    case 1:\n"
"        return texture(screen_textures[1], frag_tex_coord);\n"
"    case 2:\n"
"        return texture(screen_textures[2], frag_tex_coord);\n"
"    }\n"
"#endif\n"
"}\n"
"\n"
"void main() {\n"
"    color = GetScreen(screen_id_l);\n"
"}\n"
"\n"

};

} // namespace HostShaders
