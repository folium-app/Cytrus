// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_D24S8_TO_RGBA8_COMP = {
"// Copyright 2023 Citra Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"#extension GL_EXT_samplerless_texture_functions : require\n"
"\n"
"layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n"
"layout(set = 0, binding = 0) uniform highp texture2D depth;\n"
"layout(set = 0, binding = 1) uniform lowp utexture2D stencil;\n"
"layout(set = 0, binding = 2, rgba8) uniform highp writeonly image2D color;\n"
"\n"
"layout(push_constant, std140) uniform ComputeInfo {\n"
"    mediump ivec2 src_offset;\n"
"    mediump ivec2 dst_offset;\n"
"    mediump ivec2 extent;\n"
"};\n"
"\n"
"void main() {\n"
"    ivec2 src_coord = src_offset + ivec2(gl_GlobalInvocationID.xy);\n"
"    ivec2 dst_coord = dst_offset + ivec2(gl_GlobalInvocationID.xy);\n"
"    highp uint depth_val =\n"
"        uint(texelFetch(depth, src_coord, 0).x * (exp2(32.0) - 1.0));\n"
"    lowp uint stencil_val = texelFetch(stencil, src_coord, 0).x;\n"
"    highp uvec4 components =\n"
"        uvec4(stencil_val, (uvec3(depth_val) >> uvec3(24u, 16u, 8u)) & 0x000000FFu);\n"
"    imageStore(color, dst_coord, vec4(components) / (exp2(8.0) - 1.0));\n"
"}\n"
"\n"

};

} // namespace HostShaders
