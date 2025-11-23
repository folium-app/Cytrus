// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_DEPTH_TO_BUFFER_COMP = {
"// Copyright 2023 Citra Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"\n"
"layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n"
"layout(binding = 0) uniform highp sampler2D depth;\n"
"layout(binding = 1) uniform lowp usampler2D stencil;\n"
"\n"
"layout(binding = 2) writeonly buffer OutputBuffer{\n"
"    uint pixels[];\n"
"} staging;\n"
"\n"
"layout(push_constant, std140) uniform ComputeInfo {\n"
"    mediump ivec2 src_offset;\n"
"    mediump ivec2 dst_offset;\n"
"    mediump ivec2 extent;\n"
"};\n"
"\n"
"void main() {\n"
"    ivec2 rect = ivec2(gl_NumWorkGroups.xy) * ivec2(8);\n"
"    ivec2 dst_coord = ivec2(gl_GlobalInvocationID.xy);\n"
"    ivec2 tex_icoord = src_offset + dst_coord;\n"
"    highp vec2 tex_coord = vec2(tex_icoord) / vec2(extent);\n"
"    highp uint depth_val = uint(texture(depth, tex_coord).x * (exp2(24.0) - 1.0));\n"
"    lowp uint stencil_val = texture(stencil, tex_coord).x;\n"
"    highp uint value = stencil_val | (depth_val << 8);\n"
"    staging.pixels[dst_coord.y * rect.x + dst_coord.x] = value;\n"
"}\n"
"\n"

};

} // namespace HostShaders
