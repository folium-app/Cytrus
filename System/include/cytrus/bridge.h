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
    ASYNC_FILESYSTEM_OPERATIONS = 0,
    ASYNC_PRESENTATION = 1,
    ASYNC_SHADER_COMPILATION = 2,
    AUDIO_EMULATION_MODE = 3,
    AUDIO_STRETCHING = 4,
    CPU_CLOCK_PERCENT = 5,
    CPU_JIT = 6,
    DELAY_GAME_RENDER_THREAD_MICROSECONDS = 7, // TODO: add this? maybe no
    DETERMINISTIC_ASYNC_OPERATIONS = 8,
    DISK_SHADER_CACHE = 9,
    FAST_INTERPRETER = 10,
    GRAPHICS_API = 11,
    HARDWARE_SHADER = 12,
    INPUT_TYPE = 13,
    INTEGER_SCALING = 14,
    LOG_FILTER = 15,
    NEW_3DS_MODE = 16,
    OUTPUT_TYPE = 17,
    REALTIME_AUDIO = 18,
    REGION_FREE_PATCH = 19,
    REGION_VALUE = 20,
    REQUIRED_ONLINE_LLE_MODULES = 21,
    RESOLUTION_SCALE_FACTOR = 22,
    RIGHT_EYE_RENDER = 23,
    SHADER_JIT = 24,
    SHADERS_ACCURATE_MULTIPLY = 25,
    SIMULATE_3DS_GPU_TIMINGS = 26,
    SIMULATE_HEADPHONES_PLUGGED_IN = 27,
    SKIP_DUPLICATE_FRAMES = 28,
    SPIRV_OPTIMIZER = 29,
    SPIRV_SHADER_GENERATION = 30,
    STEPS_PER_HOUR = 31,
    TEXTURE_FILTER = 32,
    TEXTURE_SAMPLING = 33,
    VSYNC = 34,
    WEB_API_URL = 35
};

void set_setting(SETTING, bool);
void set_setting(SETTING, int);
void set_setting(SETTING, std::string);

void* context;
void set_context(void* context);

using LEDStatusChangedCallback = void(*)(void*, uint8_t, uint8_t, uint8_t);
LEDStatusChangedCallback callback;
void led_status_changed_callback(LEDStatusChangedCallback);
}
