// Copyright 2014 Tony Wasserka
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the owner nor the names of its contributors may
//       be used to endorse or promote products derived from this software
//       without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <vector>
#include <map>
#include <stdint.h>

#include "nihstro/bit_field.h"
#include "nihstro/shader_bytecode.h"
#include "nihstro/parser_shbin.h"

using namespace nihstro;

struct float24 {
    static float24 FromFloat32(float val) {
        float24 ret;
        ret.value = val;
        return ret;
    }
    
    // 16 bit mantissa, 7 bit exponent, 1 bit sign
    // TODO: No idea if this works as intended
    static float24 FromRawFloat24(uint32_t hex) {
        float24 ret;
        if ((hex & 0xFFFFFF) == 0) {
            ret.value = 0;
        } else {
            uint32_t mantissa = hex & 0xFFFF;
            uint32_t exponent = (hex >> 16) & 0x7F;
            uint32_t sign = hex >> 23;
            ret.value = std::pow(2.0f, (float)exponent-63.0f) * (1.0f + mantissa * std::pow(2.0f, -16.f));
            if (sign)
                ret.value = -ret.value;
        }
        return ret;
    }
    
    // Not recommended for anything but logging
    float ToFloat32() const {
        return value;
    }
    
private:
    // Stored as a regular float, merely for convenience
    // TODO: Perform proper arithmetic on this!
    float value;
};
