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

#include <string>
#include <iostream>
#include <sstream>
#include <fstream>

#include <stack>

#include <boost/program_options.hpp>
#include <boost/range/adaptor/reversed.hpp>
#include <boost/range/adaptor/sliced.hpp>
#include <boost/range/algorithm/count_if.hpp>

#include "nihstro/parser_assembly.h"
#include "nihstro/preprocessor.h"
#include "nihstro/source_tree.h"

#include "nihstro/shader_binary.h"
#include "nihstro/shader_bytecode.h"

#include "nihstro/float24.h"

using namespace nihstro;

enum class RegisterSpace : int {
    Input           = 0,
    Temporary       = 0x10,
    FloatUniform    = 0x20,
    Output          = 0x80,
    Address         = 0x90,
    AddressEnd      = 0x92,
    ConditionalCode = 0x93,
    IntUniform      = 0x94,
    BoolUniform     = 0x98,
    
    Max             = BoolUniform + 15,
};

// Smallest unit an expression evaluates to:
// Index to register + number of components + swizzle mask + sign
// Labels are different.
struct Atomic {
    int register_index; // TODO: Change type to RegisterSpace
    InputSwizzlerMask mask;
    bool negate;
    int relative_address_source;
    
    const RegisterType GetType() const {
        if (register_index >= (int)RegisterSpace::BoolUniform)
            return RegisterType::BoolUniform;
        else if (register_index >= (int)RegisterSpace::IntUniform)
            return RegisterType::IntUniform;
        else if (register_index >= (int)RegisterSpace::ConditionalCode)
            return RegisterType::ConditionalCode;
        else if (register_index >= (int)RegisterSpace::Address)
            return RegisterType::Address;
        else if (register_index >= (int)RegisterSpace::Output)
            return RegisterType::Output;
        else if (register_index >= (int)RegisterSpace::FloatUniform)
            return RegisterType::FloatUniform;
        else if (register_index >= (int)RegisterSpace::Temporary)
            return RegisterType::Temporary;
        else if (register_index >= (int)RegisterSpace::Input)
            return RegisterType::Input;
        else
            assert(0);
        return {};
    }
    
    int GetIndex() const {
        if (register_index >= (int)RegisterSpace::BoolUniform)
            return register_index - (int)RegisterSpace::BoolUniform;
        else if (register_index >= (int)RegisterSpace::IntUniform)
            return register_index - (int)RegisterSpace::IntUniform;
        else if (register_index >= (int)RegisterSpace::ConditionalCode)
            return register_index - (int)RegisterSpace::ConditionalCode;
        else if (register_index >= (int)RegisterSpace::Address)
            return register_index - (int)RegisterSpace::Address;
        else if (register_index >= (int)RegisterSpace::Output)
            return register_index - (int)RegisterSpace::Output;
        else if (register_index >= (int)RegisterSpace::FloatUniform)
            return register_index - (int)RegisterSpace::FloatUniform;
        else if (register_index >= (int)RegisterSpace::Temporary)
            return register_index - (int)RegisterSpace::Temporary;
        else if (register_index >= (int)RegisterSpace::Input)
            return register_index - (int)RegisterSpace::Input;
        else
            assert(0);
        return {};
    }
    
    // Returns whether this is a float uniform register OR uses relative addressing
    bool IsExtended() const {
        return GetType() == RegisterType::FloatUniform ||
        relative_address_source != 0;
    }
};

struct DestSwizzlerMask {
    DestSwizzlerMask(const InputSwizzlerMask& input) {
        std::fill(component_set, &component_set[4], false);
        for (InputSwizzlerMask::Component comp : {InputSwizzlerMask::x, InputSwizzlerMask::y,
            InputSwizzlerMask::z, InputSwizzlerMask::w}) {
                for (int i = 0; i < input.num_components; ++i) {
                    if (comp == input.components[i]) {
                        component_set[comp] = true;
                    }
                }
            }
    }
    
    bool component_set[4];
};

struct SourceSwizzlerMask {
    
    // Generate source mask according to the layout given by the destination mask
    // E.g. the source swizzle pattern used by the instruction "mov o0.zw, t0.xy" will
    // be {(undefined),(undefined),x,y} rather than {x,y,(undefined),(undefined)}.
    static SourceSwizzlerMask AccordingToDestMask(const InputSwizzlerMask& input, const DestSwizzlerMask& dest) {
        SourceSwizzlerMask ret = {Unspecified, Unspecified, Unspecified, Unspecified };
        
        int active_component = 0;
        for (int i = 0; i < 4; ++i)
            if (dest.component_set[i])
                ret.components[i] = static_cast<Component>(input.components[active_component++]);
        
        return ret;
    }
    
    static SourceSwizzlerMask Expand(const InputSwizzlerMask& input) {
        SourceSwizzlerMask ret = {Unspecified, Unspecified, Unspecified, Unspecified };
        
        for (int i = 0; i < input.num_components; ++i)
            ret.components[i] = static_cast<Component>(input.components[i]);
        
        return ret;
    }
    
    enum Component : uint8_t {
        x = 0,
        y = 1,
        z = 2,
        w = 3,
        Unspecified
    };
    Component components[4];
};

static InputSwizzlerMask MergeSwizzleMasks(const InputSwizzlerMask& inner_mask, const InputSwizzlerMask& outer_mask) {
    // TODO: Error out if the swizzle masks can't actually be merged..
    
    auto contains_component = [](const InputSwizzlerMask& swizzle_mask,const nihstro::InputSwizzlerMask::Component &c) -> bool {
        for (auto &comp : swizzle_mask.components) {
            if (comp == c)
                return true;
        }
        
        return false;
    };
    
    for (const InputSwizzlerMask::Component &c : outer_mask.components) {
        if (!contains_component(inner_mask, c))
            throw "Attempt to access component " + to_string(c) + " in vector " + to_string(inner_mask);
    }
    
    InputSwizzlerMask out;
    out.num_components = outer_mask.num_components;
    for (int comp = 0; comp < outer_mask.num_components; ++comp) {
        out.components[comp] = inner_mask.components[outer_mask.components[comp]];
    }
    
    return out;
}

static std::map<std::string, Atomic> identifier_table;

static Atomic& LookupIdentifier(const std::string& name) {
    auto it = identifier_table.find(name);
    if (it == identifier_table.end())
        throw "Unknown identifier \"" + name + "\"";
    
    return it->second;
}

// Evaluate expression to a particular Atomic
static Atomic EvaluateExpression(const Expression& expr) {
    Atomic ret = LookupIdentifier(expr.GetIdentifier());
    
    ret.negate = expr.GetSign() == -1;
    ret.relative_address_source = 0;
    
    bool relative_address_set = false;
    if (expr.HasIndexExpression()) {
        const auto& array_index_expression = expr.GetIndexExpression();
        int index = 0;
        for (int i = 0; i < array_index_expression.GetCount(); ++i) {
            if (array_index_expression.IsRawIndex(i)) {
                index += array_index_expression.GetRawIndex(i);
            } else if (array_index_expression.IsAddressRegisterIdentifier(i)) {
                if (relative_address_set) {
                    throw "May not use more than one register in relative addressing";
                }
                
                ret.relative_address_source = LookupIdentifier(array_index_expression.GetAddressRegisterIdentifier(i)).register_index;
                if (ret.relative_address_source < (int)RegisterSpace::Address ||
                    ret.relative_address_source > (int)RegisterSpace::AddressEnd) {
                    throw "Invalid register " + array_index_expression.GetAddressRegisterIdentifier(i)+ " (" + std::to_string(ret.relative_address_source) + ") used for relative addressing (only a0, a1 and lcnt are valid indexes)";
                }
                ret.relative_address_source -= (int)RegisterSpace::Address - 1; // 0 is reserved for "no dynamic indexing", hence the first address register gets value 1
                relative_address_set = true;
            }
        }
        ret.register_index += index;
    }
    // Apply swizzle mask(s)
    for (const auto& swizzle_mask : expr.GetSwizzleMasks())
        ret.mask = MergeSwizzleMasks(ret.mask, swizzle_mask);
    
    return ret;
};

// TODO: Provide optimized versions for functions without src2
static size_t FindOrAddSwizzlePattern(std::vector<SwizzlePattern>& swizzle_patterns,
                                      const DestSwizzlerMask& dest_mask,
                                      const SourceSwizzlerMask& mask_src1,
                                      const SourceSwizzlerMask& mask_src2,
                                      const SourceSwizzlerMask& mask_src3,
                                      bool negate_src1, bool negate_src2, bool negate_src3) {
    SwizzlePattern swizzle_pattern;
    swizzle_pattern.hex = 0;
    
    for (int i = 0; i < 4; ++i) {
        if (dest_mask.component_set[i])
            swizzle_pattern.SetDestComponentEnabled(i, true);
        
        if (mask_src1.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc1(i, static_cast<SwizzlePattern::Selector>(mask_src1.components[i]));
        
        if (mask_src2.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc2(i, static_cast<SwizzlePattern::Selector>(mask_src2.components[i]));
        
        if (mask_src3.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc3(i, static_cast<SwizzlePattern::Selector>(mask_src3.components[i]));
    }
    
    swizzle_pattern.negate_src1 = negate_src1;
    swizzle_pattern.negate_src2 = negate_src2;
    swizzle_pattern.negate_src3 = negate_src3;
    
    auto it = std::find_if(swizzle_patterns.begin(), swizzle_patterns.end(),
                           [&swizzle_pattern](const SwizzlePattern& val) { return val.hex == swizzle_pattern.hex; });
    if (it == swizzle_patterns.end()) {
        swizzle_patterns.push_back(swizzle_pattern);
        it = swizzle_patterns.end() - 1;
        
        if (swizzle_patterns.size() > 127)
            throw "Limit of 127 swizzle patterns has been exhausted";
    }
    
    return it - swizzle_patterns.begin();
};

static size_t FindOrAddSwizzlePattern(std::vector<SwizzlePattern>& swizzle_patterns,
                                      const DestSwizzlerMask& dest_mask,
                                      const SourceSwizzlerMask& mask_src1,
                                      const SourceSwizzlerMask& mask_src2,
                                      bool negate_src1, bool negate_src2) {
    SwizzlePattern swizzle_pattern;
    swizzle_pattern.hex = 0;
    
    for (int i = 0; i < 4; ++i) {
        if (dest_mask.component_set[i])
            swizzle_pattern.SetDestComponentEnabled(i, true);
        
        if (mask_src1.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc1(i, static_cast<SwizzlePattern::Selector>(mask_src1.components[i]));
        
        if (mask_src2.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc2(i, static_cast<SwizzlePattern::Selector>(mask_src2.components[i]));
    }
    
    swizzle_pattern.negate_src1 = negate_src1;
    swizzle_pattern.negate_src2 = negate_src2;
    
    auto it = std::find_if(swizzle_patterns.begin(), swizzle_patterns.end(),
                           [&swizzle_pattern](const SwizzlePattern& val) { return val.hex == swizzle_pattern.hex; });
    if (it == swizzle_patterns.end()) {
        swizzle_patterns.push_back(swizzle_pattern);
        it = swizzle_patterns.end() - 1;
        
        if (swizzle_patterns.size() > 127)
            throw "Limit of 127 swizzle patterns has been exhausted";
    }
    
    return it - swizzle_patterns.begin();
};

static size_t FindOrAddSwizzlePattern(std::vector<SwizzlePattern>& swizzle_patterns,
                                      const SourceSwizzlerMask& mask_src1,
                                      const SourceSwizzlerMask& mask_src2,
                                      bool negate_src1, bool negate_src2) {
    SwizzlePattern swizzle_pattern;
    swizzle_pattern.hex = 0;
    
    for (int i = 0; i < 4; ++i) {
        if (mask_src1.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc1(i, static_cast<SwizzlePattern::Selector>(mask_src1.components[i]));
        
        if (mask_src2.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc2(i, static_cast<SwizzlePattern::Selector>(mask_src2.components[i]));
    }
    
    swizzle_pattern.negate_src1 = negate_src1;
    swizzle_pattern.negate_src2 = negate_src2;
    
    auto it = std::find_if(swizzle_patterns.begin(), swizzle_patterns.end(),
                           [&swizzle_pattern](const SwizzlePattern& val) { return val.hex == swizzle_pattern.hex; });
    if (it == swizzle_patterns.end()) {
        swizzle_patterns.push_back(swizzle_pattern);
        it = swizzle_patterns.end() - 1;
        
        if (swizzle_patterns.size() > 127)
            throw "Limit of 127 swizzle patterns has been exhausted";
    }
    
    return it - swizzle_patterns.begin();
};

static size_t FindOrAddSwizzlePattern(std::vector<SwizzlePattern>& swizzle_patterns,
                                      const SourceSwizzlerMask& mask_src1,
                                      bool negate_src1) {
    SwizzlePattern swizzle_pattern;
    swizzle_pattern.hex = 0;
    
    for (int i = 0; i < 4; ++i) {
        if (mask_src1.components[i] != SourceSwizzlerMask::Unspecified)
            swizzle_pattern.SetSelectorSrc1(i, static_cast<SwizzlePattern::Selector>(mask_src1.components[i]));
    }
    
    swizzle_pattern.negate_src1 = negate_src1;
    
    auto it = std::find_if(swizzle_patterns.begin(), swizzle_patterns.end(),
                           [&swizzle_pattern](const SwizzlePattern& val) { return val.hex == swizzle_pattern.hex; });
    if (it == swizzle_patterns.end()) {
        swizzle_patterns.push_back(swizzle_pattern);
        it = swizzle_patterns.end() - 1;
        
        if (swizzle_patterns.size() > 127)
            throw "Limit of 127 swizzle patterns has been exhausted";
    }
    
    return it - swizzle_patterns.begin();
};
