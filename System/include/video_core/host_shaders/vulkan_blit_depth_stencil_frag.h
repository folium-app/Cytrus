// Copyright 2022 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#pragma once

#include <string_view>

namespace HostShaders {

constexpr std::string_view VULKAN_BLIT_DEPTH_STENCIL_FRAG = {
"// Copyright 2022 Citra Emulator Project\n"
"// Licensed under GPLv2 or any later version\n"
"// Refer to the license.txt file included.\n"
"\n"
"#version 450 core\n"
"#extension GL_ARB_shader_stencil_export : require\n"
"\n"
"layout(binding = 0) uniform sampler2D depth_tex;\n"
"layout(binding = 1) uniform usampler2D stencil_tex;\n"
"\n"
"layout(location = 0) in vec2 texcoord;\n"
"\n"
"void main() {\n"
"    gl_FragDepth = textureLod(depth_tex, texcoord, 0).r;\n"
"    gl_FragStencilRefARB = int(textureLod(stencil_tex, texcoord, 0).r);\n"
"}\n"
"\n"

};

} // namespace HostShaders
