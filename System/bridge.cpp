//
//  bridge.cpp
//  Cytrus
//
//  Created by Jarrod Norwell on 13/7/2026.
//

#include "cytrus/bridge.h"
#include "cytrus/camera.h"
#include "configuration.h"
#include "emu_window_vk.h"
#include "input_manager.h"

#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/hle/service/am/am.h"
#include "core/loader/loader.h"
#include "core/loader/smdh.h"
#include "network/network.h"

#include <codecvt>
#include <dlfcn.h>
#include <Metal.hpp>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

namespace AppleUtils {
float GetRefreshRate() { return 60.f; }
int IsLowPowerModeEnabled() { return false; }
bool IsRunningFromTerminal() { return false; }
}

// MARK: SDMH BEGIN
namespace {
    std::vector<uint8_t> GetSMDHData(const std::unique_ptr<Loader::AppLoader>& loader) {
        if (!loader) {
            printf("invalid loader\n");
            return std::vector<uint8_t>(0, 0);
        }
        
        u64 program_id{0};
        loader->ReadProgramId(program_id);
        
        std::vector<uint8_t> smdh = [program_id, &loader]() -> std::vector<u8> {
            std::vector<uint8_t> original_smdh;
            loader->ReadIcon(original_smdh);
            
            if (program_id < 0x00040000'00000000 || program_id > 0x00040000'FFFFFFFF)
                return original_smdh;
            
            std::string update_path = Service::AM::GetTitleContentPath(Service::FS::MediaType::SDMC, program_id + 0x0000000E'00000000);
            
            if (!FileUtil::Exists(update_path))
                return original_smdh;
            
            std::unique_ptr<Loader::AppLoader> update_loader = Loader::GetLoader(update_path);
            
            if (!update_loader)
                return original_smdh;
            
            std::vector<uint8_t> update_smdh;
            update_loader->ReadIcon(update_smdh);
            return update_smdh;
        }();
        
        return smdh;
    }
    
    std::vector<uint16_t> GetIcon(std::vector<uint8_t> smdh_data) {
        if (!Loader::IsValidSMDH(smdh_data)) {
            printf("invalid smdh\n");
            return std::vector<uint16_t>(0, 0);
        }
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        std::vector<uint16_t> icon_data = smdh.GetIcon(true);
        return icon_data;
    }
    
    
    std::u16string Publisher(std::vector<uint8_t> smdh_data) {
        Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
        
        if (!Loader::IsValidSMDH(smdh_data))
            return {};
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        char16_t* publisher = reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].publisher.data());
        return publisher;
    }
    
    std::string Regions(std::vector<uint8_t> smdh_data) {
        if (!Loader::IsValidSMDH(smdh_data))
            return "Invalid region";
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        using GameRegion = Loader::SMDH::GameRegion;
        static const std::map<GameRegion, const char*> regions_map = {
            {GameRegion::Japan, "Japan"},   {GameRegion::NorthAmerica, "North America"},
            {GameRegion::Europe, "Europe"}, {GameRegion::Australia, "Australia"},
            {GameRegion::China, "China"},   {GameRegion::Korea, "Korea"},
            {GameRegion::Taiwan, "Taiwan"}};
        
        std::vector<GameRegion> regions = smdh.GetRegions();
        if (regions.empty())
            return "Invalid region";
        
        const bool region_free = std::all_of(regions_map.begin(), regions_map.end(), [&regions](const auto& it) {
            return std::find(regions.begin(), regions.end(), it.first) != regions.end();
        });
        
        if (region_free)
            return "Region Free";
        
        const std::string separator = ", ";
        std::string result = regions_map.at(regions.front());
        for (auto region = ++regions.begin(); region != regions.end(); ++region)
            result += separator + regions_map.at(*region);
        
        return result;
    }
    
    std::u16string Title(std::vector<uint8_t> smdh_data) {
        Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
        
        if (!Loader::IsValidSMDH(smdh_data))
            return {};
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        std::u16string title{reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].long_title.data())};
        return title;
    }
    
    bool IsSystemTitle(std::string physical_name) {
        std::unique_ptr<Loader::AppLoader> loader = Loader::GetLoader(physical_name);
        if (!loader)
            return false;
        
        u64 program_id{0};
        loader->ReadProgramId(program_id);
        return ((program_id >> 32) & 0xFFFFFFFF) == 0x00040010;
    }
}
// MARK: SDMH END

struct cntnr {
    std::jthread thread;
    std::atomic<bool> paused, running;
    std::mutex mutex;
    std::condition_variable_any cv;
    
    CA::MetalLayer* layer;
    CA::MetalLayer* secondary_layer;
    std::shared_ptr<Common::DynamicLibrary> library;
    std::unique_ptr<EmulationWindow_Vulkan> window, secondary_window;
    double height, width;
    double secondary_height, secondary_width;
} cntnr;


void cytrus::print_about(void) {
    printf("Welcome to Cytrus\n");
    printf("Nintendo 3DS emulator based on Azahar\n");
}


void cytrus::initialize_logging(void) {
    Common::Log::Initialize();
    Common::Log::SetColorConsoleBackendEnabled(false);
    Common::Log::Start();
    
    Common::Log::Filter filter;
    filter.ParseFilterString(Settings::values.log_filter.GetValue());
    Common::Log::SetGlobalFilter(filter);
    
    Config{};
    
    Settings::values.aspect_ratio.SetValue(Settings::AspectRatio::Stretch);
    Settings::values.layout_option.SetValue(Settings::LayoutOption::SeparateWindows);
    
    cntnr.library = std::make_shared<Common::DynamicLibrary>(dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW));
    
    SDL_SetMainReady();
}


static uint16_t empty[48 * 48]{};
void* cytrus::icon_from_disc(std::string path) {
    auto loader = Loader::GetLoader(path);
    auto sdmh = GetSMDHData(loader);
    auto icon = GetIcon(sdmh);
    
    if (icon.size() > 0)
        return icon.data();
    else
        return empty;
}

std::string cytrus::title_from_disc(std::string path) {
    auto loader = Loader::GetLoader(path);
    auto sdmh = GetSMDHData(loader);
    auto title = Title(sdmh);
    
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    return convert.to_bytes(title);
}


void cytrus::insert_disc(std::string path) {
    Core::System& system{Core::System::GetInstance()};
    
    cntnr.window.release();
    cntnr.window = std::make_unique<EmulationWindow_Vulkan>(cntnr.layer, false, cntnr.library, cntnr.height, cntnr.width);
    
    cntnr.secondary_window.release();
    cntnr.secondary_window = std::make_unique<EmulationWindow_Vulkan>(cntnr.secondary_layer, true, cntnr.library,
                                                                      cntnr.secondary_height, cntnr.secondary_width);
    
    uint64_t program_id{0};
    FileUtil::SetCurrentRomPath(path);
    auto loader = Loader::GetLoader(path);
    if (loader)
        loader->ReadProgramId(program_id);
    
    Frontend::RegisterDefaultApplets(system);
    system.RegisterInfoLEDColorChanged([&]() {
        const auto& color = system.GetInfoLEDColor();
        cytrus::callback(cytrus::context, color.x, color.y, color.z);
    });
    
    system.ApplySettings();
    Settings::LogSettings();
    
    auto frontCamera = std::make_unique<Camera::iOSFrontCameraFactory>();
    auto leftRearCamera = std::make_unique<Camera::iOSLeftRearCameraFactory>();
    auto rightRearCamera = std::make_unique<Camera::iOSRightRearCameraFactory>();
    Camera::RegisterFactory("av_front", std::move(frontCamera));
    Camera::RegisterFactory("av_rear_left", std::move(leftRearCamera));
    Camera::RegisterFactory("av_rear_right", std::move(rightRearCamera));
    
    InputManager::Init();
    Network::Init();
    
    void(system.Load(*cntnr.window, path, cntnr.secondary_window.get()));
}


bool cytrus::is_paused(bool change, bool set_paused) {
    if (change)
        cntnr.paused.store(set_paused);
    
    if (change && !set_paused)
        cntnr.cv.notify_one();
    
    return cntnr.paused.load();
}

bool cytrus::is_running(bool change, bool set_running) {
    if (change)
        cntnr.running.store(set_running);
    return cntnr.running.load();
}


void cytrus::start(void) {
    Core::System& system{Core::System::GetInstance()};
    
    cntnr.thread = std::jthread([&](std::stop_token token) {
        while (cntnr.running.load()) {
            if (cntnr.paused.load())
                continue;
            
            void(system.RunLoop());
        }
    });
}


void cytrus::stop(void) {
    cntnr.paused.store(false);
    cntnr.running.store(false);
    
    Core::System& system{Core::System::GetInstance()};
    system.RequestShutdown();
    system.Shutdown();
    
    InputManager::Shutdown();
    Network::Shutdown();
}


void cytrus::set_screens(void* layer, double height, double width, bool secondary) {
    if (secondary) {
        cntnr.secondary_layer = static_cast<CA::MetalLayer*>(layer);
        cntnr.secondary_height = height;
        cntnr.secondary_width = width;
    } else {
        cntnr.layer = static_cast<CA::MetalLayer*>(layer);
        cntnr.height = height;
        cntnr.width = width;
    }
}


void cytrus::press_button(int button) {
    if (auto handler = InputManager::ButtonHandler())
        handler->PressKey(button);
}

void cytrus::release_button(int button) {
    if (auto handler = InputManager::ButtonHandler())
        handler->ReleaseKey(button);
}


void cytrus::touch_began(float x, float y) {
    if (auto bottom = cntnr.secondary_window.get())
        bottom->TouchPressed(x, y);
}

void cytrus::touch_ended(void) {
    if (auto bottom = cntnr.secondary_window.get())
        bottom->TouchReleased();
}

void cytrus::touch_moved(float x, float y) {
    cytrus::touch_began(x, y);
}

void cytrus::move_thumbstick(int id, float x, float y) {
    if (auto handler = InputManager::AnalogHandler())
        handler->MoveJoystick(id, x, y);
}

void cytrus::set_setting(cytrus::SETTING setting, bool value) {
    switch (setting) {
        case SETTING::ASYNC_FILESYSTEM_OPERATIONS:
            Settings::values.async_fs_operations.SetValue(value);
            break;
        case SETTING::ASYNC_PRESENTATION:
            Settings::values.async_presentation.SetValue(value);
            break;
        case SETTING::ASYNC_SHADER_COMPILATION:
            Settings::values.async_shader_compilation.SetValue(value);
            break;
        case SETTING::AUDIO_EMULATION_MODE:
            break;
        case SETTING::AUDIO_STRETCHING:
            Settings::values.enable_audio_stretching.SetValue(value);
            break;
        case SETTING::CPU_CLOCK_PERCENT:
            break;
        case SETTING::CPU_JIT:
            Settings::values.use_cpu_jit.SetValue(value);
            break;
        case SETTING::DELAY_GAME_RENDER_THREAD_MICROSECONDS:
            break;
        case SETTING::DETERMINISTIC_ASYNC_OPERATIONS:
            Settings::values.deterministic_async_operations.SetValue(value);
            break;
        case SETTING::DISK_SHADER_CACHE:
            Settings::values.use_disk_shader_cache.SetValue(value);
            break;
        case SETTING::FAST_INTERPRETER:
            Settings::values.use_fastinterp.SetValue(value);
            break;
            break;
        case SETTING::GRAPHICS_API:
            break;
        case SETTING::HARDWARE_SHADER:
            Settings::values.use_hw_shader.SetValue(value);
            break;
        case SETTING::INPUT_TYPE:
            break;
        case SETTING::INTEGER_SCALING:
            Settings::values.use_integer_scaling.SetValue(value);
            break;
        case SETTING::LOG_FILTER:
            break;
        case SETTING::NEW_3DS_MODE:
            Settings::values.is_new_3ds.SetValue(value);
            break;
        case SETTING::OUTPUT_TYPE:
            break;
        case SETTING::REALTIME_AUDIO:
            Settings::values.enable_realtime_audio.SetValue(value);
            break;
        case SETTING::REGION_FREE_PATCH:
            Settings::values.apply_region_free_patch.SetValue(value);
            break;
        case SETTING::REGION_VALUE:
            break;
        case SETTING::REQUIRED_ONLINE_LLE_MODULES:
            Settings::values.enable_required_online_lle_modules.SetValue(value);
            break;
        case SETTING::RESOLUTION_SCALE_FACTOR:
            break;
        case SETTING::RIGHT_EYE_RENDER:
            Settings::values.disable_right_eye_render.SetValue(!value);
            break;
        case SETTING::SHADER_JIT:
            Settings::values.use_shader_jit.SetValue(value);
            break;
        case SETTING::SHADERS_ACCURATE_MULTIPLY:
            Settings::values.shaders_accurate_mul.SetValue(value);
            break;
        case SETTING::SIMULATE_3DS_GPU_TIMINGS:
            Settings::values.simulate_3ds_gpu_timings.SetValue(value);
            break;
        case SETTING::SIMULATE_HEADPHONES_PLUGGED_IN:
            Settings::values.simulate_headphones_plugged.SetValue(value);
            break;
        case SETTING::SKIP_DUPLICATE_FRAMES:
            Settings::values.use_skip_duplicate_frames.SetValue(value);
            break;
        case SETTING::SPIRV_OPTIMIZER:
            Settings::values.disable_spirv_optimizer.SetValue(!value);
            break;
        case SETTING::SPIRV_SHADER_GENERATION:
            Settings::values.spirv_shader_gen.SetValue(value);
            break;
        case SETTING::STEPS_PER_HOUR:
            break;
        case SETTING::TEXTURE_FILTER:
            break;
        case SETTING::TEXTURE_SAMPLING:
            break;
        case SETTING::VSYNC:
            Settings::values.use_vsync.SetValue(value);
            break;
        case SETTING::WEB_API_URL:
            break;
    }
}

void cytrus::set_setting(cytrus::SETTING setting, int value) {
    switch (setting) {
        case SETTING::ASYNC_FILESYSTEM_OPERATIONS:
            break;
        case SETTING::ASYNC_PRESENTATION:
            break;
        case SETTING::ASYNC_SHADER_COMPILATION:
            break;
        case SETTING::AUDIO_EMULATION_MODE:
            Settings::values.audio_emulation.SetValue(static_cast<Settings::AudioEmulation>(value));
            break;
        case SETTING::AUDIO_STRETCHING:
            break;
        case SETTING::CPU_CLOCK_PERCENT:
            Settings::values.cpu_clock_percentage.SetValue(static_cast<u32>(value));
            break;
        case SETTING::CPU_JIT:
            break;
        case SETTING::DELAY_GAME_RENDER_THREAD_MICROSECONDS:
            Settings::values.delay_game_render_thread_us.SetValue(static_cast<u16>(value));
            break;
        case SETTING::DETERMINISTIC_ASYNC_OPERATIONS:
            break;
        case SETTING::DISK_SHADER_CACHE:
            break;
        case SETTING::FAST_INTERPRETER:
            break;
            break;
        case SETTING::GRAPHICS_API:
            Settings::values.graphics_api.SetValue(static_cast<Settings::GraphicsAPI>(value));
            break;
        case SETTING::HARDWARE_SHADER:
            break;
        case SETTING::INPUT_TYPE:
            Settings::values.input_type.SetValue(static_cast<AudioCore::InputType>(value));
            break;
        case SETTING::INTEGER_SCALING:
            break;
        case SETTING::LOG_FILTER:
            break;
        case SETTING::NEW_3DS_MODE:
            break;
        case SETTING::OUTPUT_TYPE:
            Settings::values.output_type.SetValue(static_cast<AudioCore::SinkType>(value));
            break;
        case SETTING::REALTIME_AUDIO:
            break;
        case SETTING::REGION_FREE_PATCH:
            break;
        case SETTING::REGION_VALUE:
            Settings::values.region_value.SetValue(static_cast<s32>(value));
            break;
        case SETTING::REQUIRED_ONLINE_LLE_MODULES:
            break;
        case SETTING::RESOLUTION_SCALE_FACTOR:
            Settings::values.resolution_factor.SetValue(static_cast<u32>(value));
            break;
        case SETTING::RIGHT_EYE_RENDER:
            break;
        case SETTING::SHADER_JIT:
            break;
        case SETTING::SHADERS_ACCURATE_MULTIPLY:
            break;
        case SETTING::SIMULATE_3DS_GPU_TIMINGS:
            break;
        case SETTING::SIMULATE_HEADPHONES_PLUGGED_IN:
            break;
        case SETTING::SKIP_DUPLICATE_FRAMES:
            break;
        case SETTING::SPIRV_OPTIMIZER:
            break;
        case SETTING::SPIRV_SHADER_GENERATION:
            break;
        case SETTING::STEPS_PER_HOUR:
            Settings::values.steps_per_hour.SetValue(static_cast<u16>(value));
            break;
        case SETTING::TEXTURE_FILTER:
            Settings::values.texture_filter.SetValue(static_cast<Settings::TextureFilter>(value));
            break;
        case SETTING::TEXTURE_SAMPLING:
            Settings::values.texture_sampling.SetValue(static_cast<Settings::TextureSampling>(value));
            break;
        case SETTING::VSYNC:
            break;
        case SETTING::WEB_API_URL:
            break;
    }
}

void cytrus::set_setting(cytrus::SETTING setting, std::string value) {
    switch (setting) {
        case SETTING::ASYNC_FILESYSTEM_OPERATIONS:
            break;
        case SETTING::ASYNC_PRESENTATION:
            break;
        case SETTING::ASYNC_SHADER_COMPILATION:
            break;
        case SETTING::AUDIO_EMULATION_MODE:
            break;
        case SETTING::AUDIO_STRETCHING:
            break;
        case SETTING::CPU_CLOCK_PERCENT:
            break;
        case SETTING::CPU_JIT:
            break;
        case SETTING::DELAY_GAME_RENDER_THREAD_MICROSECONDS:
            break;
        case SETTING::DETERMINISTIC_ASYNC_OPERATIONS:
            break;
        case SETTING::DISK_SHADER_CACHE:
            break;
        case SETTING::FAST_INTERPRETER:
            break;
            break;
        case SETTING::GRAPHICS_API:
            break;
        case SETTING::HARDWARE_SHADER:
            break;
        case SETTING::INPUT_TYPE:
            break;
        case SETTING::INTEGER_SCALING:
            break;
        case SETTING::LOG_FILTER:
            Settings::values.log_filter.SetValue(value);
            break;
        case SETTING::NEW_3DS_MODE:
            break;
        case SETTING::OUTPUT_TYPE:
            break;
        case SETTING::REALTIME_AUDIO:
            break;
        case SETTING::REGION_FREE_PATCH:
            break;
        case SETTING::REGION_VALUE:
            break;
        case SETTING::REQUIRED_ONLINE_LLE_MODULES:
            break;
        case SETTING::RESOLUTION_SCALE_FACTOR:
            break;
        case SETTING::RIGHT_EYE_RENDER:
            break;
        case SETTING::SHADER_JIT:
            break;
        case SETTING::SHADERS_ACCURATE_MULTIPLY:
            break;
        case SETTING::SIMULATE_3DS_GPU_TIMINGS:
            break;
        case SETTING::SIMULATE_HEADPHONES_PLUGGED_IN:
            break;
        case SETTING::SKIP_DUPLICATE_FRAMES:
            break;
        case SETTING::SPIRV_OPTIMIZER:
            break;
        case SETTING::SPIRV_SHADER_GENERATION:
            break;
        case SETTING::STEPS_PER_HOUR:
            break;
        case SETTING::TEXTURE_FILTER:
            break;
        case SETTING::TEXTURE_SAMPLING:
            break;
        case SETTING::VSYNC:
            break;
        case SETTING::WEB_API_URL:
            Settings::values.web_api_url.SetValue(value);
            break;
    }
}

void cytrus::set_context(void* context) {
    cytrus::context = context;
}

void cytrus::led_status_changed_callback(cytrus::LEDStatusChangedCallback callback) {
    cytrus::callback = callback;
}
