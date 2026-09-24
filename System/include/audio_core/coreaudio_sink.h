//
//  coreaudio_sink.hpp
//  Cytrus
//
//  Created by Jarrod Norwell on 13/1/2025.
//  Copyright © 2025 Jarrod Norwell. All rights reserved.
//

#pragma once

#include <AudioUnit/AudioUnit.h>
#include <cstddef>

#include "audio_core/sink.h"

namespace AudioCore {
class CoreAudioSink final : public Sink {
public:
    explicit CoreAudioSink(std::string device_id);
    ~CoreAudioSink() override;

    unsigned int GetNativeSampleRate() const override;

    void SetCallback(std::function<void(s16*, std::size_t)> cb) override;

private:
    AudioUnit audio_unit;
    std::function<void(s16*, std::size_t)> cb = nullptr;

    static OSStatus NativeCallback(void* ref_con, AudioUnitRenderActionFlags* action_flags, const AudioTimeStamp* timestamp, UInt32 bus_number, UInt32 number_frames, AudioBufferList* data);
};

std::vector<std::string> ListCoreAudioSinkDevices();
}
