//
//  bridge.h
//  Cytrus
//
//  Created by Jarrod Norwell on 13/7/2026.
//

#include <cstdint>
#include <string>

namespace cytrus {
void print_about(void);

void initialize_logging(void);

void* icon_from_disc(std::string);
std::string title_from_disc(std::string);

void insert_disc(std::string);

bool is_paused(bool = false, bool = false);
bool is_running(bool = false, bool = false);

void start(void), stop(void);

void set_screens(void*, double, double, bool);

void press_button(int), release_button(int);
void touch_began(float, float), touch_ended(void), touch_moved(float, float);

void move_thumbstick(int, float, float);

enum class SETTING {
    LLE_APPLETS = 0,
    DETERMINISTIC_ASYNC_OPERATIONS = 1,
    REQUIRED_ONLINE_LLE_MODULES = 2,
    REGION_PREF_PATCH = 3,
    SWAP_EYES_3D = 4,
    SPIRV_SHADER_GEN = 5,
    SPIRV_OPTIMIZER = 6,
    ASYNC_SHADER_COMPILATION = 7,
    ASYNC_PRESENTATION = 8,
    DISK_SHADER_CACHE = 9,
    VSYNC = 10,
    SHADER_ACCURATE_MULTIPLICATION = 11,
    SOUND_STRETCHING = 12,
    REALTIME_SOUND = 13
};

void set_setting(SETTING, bool);

void* context;
void set_context(void* context);

using LEDStatusChangedCallback = void(*)(void*, uint8_t, uint8_t, uint8_t);
LEDStatusChangedCallback callback;
void led_status_changed_callback(LEDStatusChangedCallback);
}
