//
//  coreaudio_input.h
//  Folium
//
//  Created by Jarrod Norwell on 17/7/2026.
//

#pragma once

#include <memory>
#include <string>
#include <vector>
#include "audio_core/input.h"

namespace AudioCore {

class CoreAudioInput final : public Input {
public:
    explicit CoreAudioInput(std::string device_id);
    ~CoreAudioInput() override;

    void StartSampling(const InputParameters& params) override;
    void StopSampling() override;
    bool IsSampling() override;
    void AdjustSampleRate(u32 sample_rate) override;
    Samples Read() override;

public:
    struct Impl;
    std::unique_ptr<Impl> impl;
    std::string device_id;
};

std::vector<std::string> ListCoreAudioInputDevices();

} // namespace AudioCore
