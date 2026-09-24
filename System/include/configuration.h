//
//  configuration.h
//  Cytrus
//
//  Created by Jarrod Norwell on 13/7/2026.
//

#pragma once

#include <memory>
#include <string>

#include "common/settings.h"

class INIReader;

class Config {
private:
    std::unique_ptr<INIReader> sdl3_config;
    std::string sdl3_config_loc;

    bool LoadINI(const std::string& default_contents = "", bool retry = true);
    void ReadValues();

public:
    Config();
    ~Config();

    void Reload();

private:
    /**
     * Applies a value read from the android_config to a Setting.
     *
     * @param group The name of the INI group
     * @param setting The yuzu setting to modify
     */
    template <typename Type, bool ranged>
    void ReadSetting(const std::string& group, Settings::Setting<Type, ranged>& setting);
};
