//
//  Configuration.h
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#pragma once

#include <memory>
#include <string>
#include "common/settings.h"

class INIReader;

class Configuration {
private:
    std::unique_ptr<INIReader> sdl2_config;
    std::string sdl2_config_loc;

    bool LoadINI(const std::string& default_contents = "", bool retry = true);
    void ReadValues();

public:
    Configuration();
    ~Configuration();

    void Reload();

private:
    /**
     * Applies a value read from the sdl2_config to a Setting.
     *
     * @param group The name of the INI group
     * @param setting The yuzu setting to modify
     */
    template <typename Type, bool ranged>
    void ReadSetting(const std::string& group, Settings::Setting<Type, ranged>& setting);
};
