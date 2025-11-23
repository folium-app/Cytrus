// Copyright 2023 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include <algorithm>
#include <memory>
#include <string>
#include <vector>
#include "audio_core/input_details.h"
#include "audio_core/null_input.h"
#include "audio_core/static_input.h"
#include "audio_core/openal_input.h"
#include "common/logging/log.h"
#include "core/core.h"

namespace AudioCore {
namespace {
// input_details is ordered in terms of desirability, with the best choice at the top.
constexpr std::array input_details = {
    InputDetails{InputType::OpenAL, "Real Device (OpenAL)", true,
                 [](Core::System& system, std::string_view device_id) -> std::unique_ptr<Input> {
                     if (!system.HasMicPermission()) {
                         LOG_WARNING(Audio,
                                     "Microphone permission denied, falling back to null input.");
                         return std::make_unique<NullInput>();
                     }
                     return std::make_unique<OpenALInput>(std::string(device_id));
                 },
                 &ListOpenALInputDevices},
    InputDetails{InputType::Static, "Static Noise", false,
                 [](Core::System& system, std::string_view device_id) -> std::unique_ptr<Input> {
                     return std::make_unique<StaticInput>();
                 },
                 [] { return std::vector<std::string>{"Static Noise"}; }},
    InputDetails{InputType::Null, "None", false,
                 [](Core::System& system, std::string_view device_id) -> std::unique_ptr<Input> {
                     return std::make_unique<NullInput>();
                 },
                 [] { return std::vector<std::string>{"None"}; }},
};
} // Anonymous namespace

std::vector<InputDetails> ListInputs() {
    return {input_details.begin(), input_details.end()};
}

const InputDetails& GetInputDetails(InputType input_type) {
    auto iter = std::find_if(
        input_details.begin(), input_details.end(),
        [input_type](const auto& input_detail) { return input_detail.type == input_type; });

    if (input_type == InputType::Auto || iter == input_details.end()) {
        if (input_type != InputType::Auto) {
            LOG_ERROR(Audio, "AudioCore::GetInputDetails given invalid input_type {}", input_type);
        }
        // Auto-select.
        // input_details is ordered in terms of desirability, with the best choice at the front.
        iter = input_details.begin();
    }

    return *iter;
}

} // namespace AudioCore
