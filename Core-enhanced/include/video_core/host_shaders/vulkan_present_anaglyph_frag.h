// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_PRESENT_ANAGLYPH_FRAG = {
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
"// Rendepth: Red/Cyan Anaglyph Filter Optimized for Stereoscopic 3D on LCD Monitors by Andres Hernandez.\n"
"// Based on the paper 'Producing Anaglyphs from Synthetic Images' by William Sanders, David F. McAllister.\n"
"// Using concepts from 'Methods for computing color anaglyphs' by David F. McAllister, Ya Zhou, Sophia Sullivan.\n"
"// Original research from 'Conversion of a Stereo Pair to Anaglyph with the Least-Squares Projection Method' by Eric Dubois\n"
"\n"
"const mat3 l = mat3(\n"
"    vec3(0.4561, 0.500484, 0.176381),\n"
"    vec3(-0.400822, -0.0378246, -0.0157589),\n"
"    vec3(-0.0152161, -0.0205971, -0.00546856));\n"
"\n"
"const mat3 r = mat3(\n"
"    vec3(-0.0434706, -0.0879388, -0.00155529),\n"
"    vec3(0.378476, 0.73364, -0.0184503),\n"
"    vec3(-0.0721527, -0.112961, 1.2264));\n"
"\n"
"const vec3 g = vec3(1.6, 0.8, 1.0);\n"
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
"vec3 correct_color(vec3 col) {\n"
"    vec3 result;\n"
"    result.r = pow(col.r, 1.0 / g.r);\n"
"    result.g = pow(col.g, 1.0 / g.g);\n"
"    result.b = pow(col.b, 1.0 / g.b);\n"
"    return result;\n"
"}\n"
"\n"
"void main() {\n"
"    vec4 color_tex_l = GetScreen(screen_id_l);\n"
"    vec4 color_tex_r = GetScreen(screen_id_r);\n"
"    vec3 color_anaglyph = clamp(color_tex_l.rgb * l, vec3(0.0), vec3(1.0)) + clamp(color_tex_r.rgb * r, vec3(0.0), vec3(1.0));\n"
"    vec3 color_corrected = correct_color(color_anaglyph);\n"
"    color = vec4(color_corrected, color_tex_l.a);\n"
"}\n"
"\n"

};

} // namespace HostShaders