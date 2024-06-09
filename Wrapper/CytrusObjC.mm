//
//  CytrusObjC.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 1/8/24.
//

#import "CytrusObjC.h"

#include "Configuration/Configuration.h"
#include "EmulationWindow/EmulationWindow_Vulkan.h"
#include "InputManager/InputManager.h"

#include <dlfcn.h>
#include <memory>

#include "common/dynamic_library/dynamic_library.h"
#include "common/scope_exit.h"
#include "common/settings.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/hle/service/am/am.h"
#include "core/loader/loader.h"

#include <future>
#include <thread>
#include <map>

#include "core/frontend/applets/swkbd.h"
#include "video_core/gpu.h"
#include "video_core/renderer_base.h"

namespace SoftwareKeyboard {

class Keyboard final : public Frontend::SoftwareKeyboard {
public:
    ~Keyboard();
    
    void Execute(const Frontend::KeyboardConfig& config) override;
    void ShowError(const std::string& error) override;
    
    void KeyboardText(std::condition_variable& cv);
    std::pair<std::string, uint8_t> GetKeyboardText(const Frontend::KeyboardConfig& config);
    
private:
    __block NSString *_Nullable keyboardText = @"";
    __block uint8_t buttonPressed = 0;
    
    __block BOOL isReady = FALSE;
};

} // namespace SoftwareKeyboard


//

@implementation KeyboardConfig
-(KeyboardConfig *) initWithHintText:(NSString *)hintText buttonConfig:(KeyboardButtonConfig)buttonConfig {
    if (self = [super init]) {
        self.hintText = hintText;
        self.buttonConfig = buttonConfig;
    } return self;
}
@end

namespace SoftwareKeyboard {

Keyboard::~Keyboard() = default;

void Keyboard::Execute(const Frontend::KeyboardConfig& config) {
    SoftwareKeyboard::Execute(config);
    
    std::pair<std::string, uint8_t> it = this->GetKeyboardText(config);
    if (this->config.button_config != Frontend::ButtonConfig::None)
        it.second = static_cast<uint8_t>(this->config.button_config);
    
    NSLog(@"%d, %d", ValidateFilters(it.first), ValidateInput(it.first));
    
    Finalize(it.first, it.second);
}

void Keyboard::ShowError(const std::string& error) {
    printf("error = %s\n", error.c_str());
}

void Keyboard::KeyboardText(std::condition_variable& cv) {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"closeKeyboard" object:NULL queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notification) {
        this->buttonPressed = (NSUInteger)notification.userInfo[@"buttonPressed"];
        
        NSString *_Nullable text = notification.userInfo[@"keyboardText"];
        if (text != NULL)
            this->keyboardText = text;
        
        isReady = TRUE;
        cv.notify_all();
    }];
}

std::pair<std::string, uint8_t> Keyboard::GetKeyboardText(const Frontend::KeyboardConfig& config) {
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"openKeyboard"
                                                                                         object:[[KeyboardConfig alloc] initWithHintText:[NSString stringWithCString:config.hint_text.c_str() encoding:NSUTF8StringEncoding] buttonConfig:(KeyboardButtonConfig)config.button_config]]];
    
    std::condition_variable cv;
    std::mutex mutex;
    auto t1 = std::async(&Keyboard::KeyboardText, this, std::ref(cv));
    std::unique_lock<std::mutex> lock(mutex);
    while (!isReady)
        cv.wait(lock);
    
    return std::make_pair([this->keyboardText UTF8String], this->buttonPressed);
}
}

//

std::unique_ptr<EmulationWindow_Vulkan> window, window2;
std::shared_ptr<Common::DynamicLibrary> library;

static void TryShutdown() {
    if (!window)
        return;
    
    window->DoneCurrent();
    Core::System::GetInstance().Shutdown();
    window.reset();
    InputManager::Shutdown();
};

@implementation CytrusObjC
-(CytrusObjC *) init {
    if (self = [super init]) {
        _gameInformation = [GameInformation sharedInstance];
        
        Common::Log::Initialize();
        Common::Log::SetColorConsoleBackendEnabled(true);
        Common::Log::Start();
        
        Common::Log::Filter filter;
        filter.ParseFilterString(Settings::values.log_filter.GetValue());
        Common::Log::SetGlobalFilter(filter);
    } return self;
}

+(CytrusObjC *) sharedInstance {
    static dispatch_once_t onceToken;
    static CytrusObjC *sharedInstance = NULL;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) getVulkanLibrary {
    library = std::make_shared<Common::DynamicLibrary>(dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW));
}

-(void) setMTKView:(MTKView *)mtkView size:(CGSize)size {
    _size = size;
    _mtkView = mtkView;
    window = std::make_unique<EmulationWindow_Vulkan>((__bridge CA::MetalLayer*)self->_mtkView.layer, library, false, self->_size);
    window->MakeCurrent();
}

-(void) run:(NSURL *)url {
    std::scoped_lock lock(running_mutex);
    
    Core::System& system{Core::System::GetInstance()};
    
    Config config;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.cpuClockPercentage"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([defaults boolForKey:@"cytrus.useNew3DS"]);
    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.useLLEApplets"]);
    
    Settings::values.region_value.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.regionSelect"]] intValue]);
    
    Settings::values.spirv_shader_gen.SetValue([defaults boolForKey:@"cytrus.spirvShaderGeneration"]);
    Settings::values.async_shader_compilation.SetValue([defaults boolForKey:@"cytrus.useAsyncShaderCompilation"]);
    Settings::values.async_presentation.SetValue([defaults boolForKey:@"cytrus.useAsyncPresentation"]);
    Settings::values.use_hw_shader.SetValue([defaults boolForKey:@"cytrus.useHardwareShaders"]);
    Settings::values.use_disk_shader_cache.SetValue([defaults boolForKey:@"cytrus.useDiskShaderCache"]);
    Settings::values.shaders_accurate_mul.SetValue([defaults boolForKey:@"cytrus.useShadersAccurateMul"]);
    Settings::values.use_vsync_new.SetValue([defaults boolForKey:@"cytrus.useNewVSync"]);
    Settings::values.resolution_factor.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.resolutionFactor"]] unsignedIntValue]);
    Settings::values.use_shader_jit.SetValue([defaults boolForKey:@"cytrus.useShaderJIT"]);
    Settings::values.texture_filter.SetValue((Settings::TextureFilter)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.textureFilter"]] unsignedIntValue]);
    Settings::values.texture_sampling.SetValue((Settings::TextureSampling)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.textureSampling"]] unsignedIntValue]);
    
    Settings::values.layout_option.SetValue((Settings::LayoutOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.layoutOption"]] unsignedIntValue]);
    
    Settings::values.render_3d.SetValue((Settings::StereoRenderOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.render3D"]] unsignedIntValue]);
    Settings::values.mono_render_option.SetValue((Settings::MonoRenderOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.monoRender"]] unsignedIntValue]);
    
    Settings::values.custom_textures.SetValue([defaults boolForKey:@"cytrus.useCustomTextures"]);
    Settings::values.preload_textures.SetValue([defaults boolForKey:@"cytrus.preloadTextures"]);
    Settings::values.async_custom_loading.SetValue([defaults boolForKey:@"cytrus.asyncCustomLoading"]);
    
    Settings::values.audio_emulation.SetValue((Settings::AudioEmulation)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioEmulation"]] unsignedIntValue]);
    Settings::values.enable_audio_stretching.SetValue([defaults boolForKey:@"cytrus.audioStretching"]);
    Settings::values.output_type.SetValue((AudioCore::SinkType)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioOutputDevice"]] unsignedIntValue]);
    Settings::values.input_type.SetValue((AudioCore::InputType)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioInputDevice"]] unsignedIntValue]);
    
    Settings::values.custom_layout.SetValue([defaults boolForKey:@"cytrus.useCustomLayout"]);
    Settings::values.custom_top_left.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopLeft"]] unsignedIntValue]);
    Settings::values.custom_top_top.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopTop"]] unsignedIntValue]);
    Settings::values.custom_top_right.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopRight"]] unsignedIntValue]);
    Settings::values.custom_top_bottom.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopBottom"]] unsignedIntValue]);
    Settings::values.custom_bottom_left.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomLeft"]] unsignedIntValue]);
    Settings::values.custom_bottom_top.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomTop"]] unsignedIntValue]);
    Settings::values.custom_bottom_right.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomRight"]] unsignedIntValue]);
    Settings::values.custom_bottom_bottom.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomBottom"]] unsignedIntValue]);
    
    system.ApplySettings();
    Settings::LogSettings();
    
    Frontend::RegisterDefaultApplets(system);
    // system.RegisterMiiSelector(std::make_shared<MiiSelector::AndroidMiiSelector>());
    system.RegisterSoftwareKeyboard(std::make_shared<SoftwareKeyboard::Keyboard>());
    
    InputManager::Init();
    
    void(system.Load(*window, [url.path UTF8String]));
    
    stop_run = false;
    pause_emulation = false;
    
    std::unique_ptr<Frontend::GraphicsContext> cpu_context;
    system.GPU().Renderer().Rasterizer()->LoadDiskResources(stop_run, [](VideoCore::LoadCallbackStage, std::size_t, std::size_t) {});
    
    SCOPE_EXIT({
        TryShutdown();
    });
    
    while (!stop_run) {
        if (!pause_emulation) {
            void(system.RunLoop());
        } else {
            const float volume = Settings::values.volume.GetValue();
            SCOPE_EXIT({
                Settings::values.volume = volume;
            });
            Settings::values.volume = 0;

            std::unique_lock pause_lock{paused_mutex};
            running_cv.wait(pause_lock, [&] {
                return !pause_emulation || stop_run;
            });
            window->PollEvents();
        }
    }
}

-(void) updateSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.cpuClockPercentage"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([defaults boolForKey:@"cytrus.useNew3DS"]);
    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.useLLEApplets"]);
    
    Settings::values.region_value.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.regionSelect"]] intValue]);
    
    Settings::values.spirv_shader_gen.SetValue([defaults boolForKey:@"cytrus.spirvShaderGeneration"]);
    Settings::values.async_shader_compilation.SetValue([defaults boolForKey:@"cytrus.useAsyncShaderCompilation"]);
    Settings::values.async_presentation.SetValue([defaults boolForKey:@"cytrus.useAsyncPresentation"]);
    Settings::values.use_hw_shader.SetValue([defaults boolForKey:@"cytrus.useHardwareShaders"]);
    Settings::values.use_disk_shader_cache.SetValue([defaults boolForKey:@"cytrus.useDiskShaderCache"]);
    Settings::values.shaders_accurate_mul.SetValue([defaults boolForKey:@"cytrus.useShadersAccurateMul"]);
    Settings::values.use_vsync_new.SetValue([defaults boolForKey:@"cytrus.useNewVSync"]);
    Settings::values.resolution_factor.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.resolutionFactor"]] unsignedIntValue]);
    Settings::values.use_shader_jit.SetValue([defaults boolForKey:@"cytrus.useShaderJIT"]);
    Settings::values.texture_filter.SetValue((Settings::TextureFilter)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.textureFilter"]] unsignedIntValue]);
    Settings::values.texture_sampling.SetValue((Settings::TextureSampling)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.textureSampling"]] unsignedIntValue]);
    
    Settings::values.layout_option.SetValue((Settings::LayoutOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.layoutOption"]] unsignedIntValue]);
    
    Settings::values.render_3d.SetValue((Settings::StereoRenderOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.render3D"]] unsignedIntValue]);
    Settings::values.mono_render_option.SetValue((Settings::MonoRenderOption)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.monoRender"]] unsignedIntValue]);
    
    Settings::values.custom_textures.SetValue([defaults boolForKey:@"cytrus.useCustomTextures"]);
    Settings::values.preload_textures.SetValue([defaults boolForKey:@"cytrus.preloadTextures"]);
    Settings::values.async_custom_loading.SetValue([defaults boolForKey:@"cytrus.asyncCustomLoading"]);
    
    Settings::values.audio_emulation.SetValue((Settings::AudioEmulation)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioEmulation"]] unsignedIntValue]);
    Settings::values.enable_audio_stretching.SetValue([defaults boolForKey:@"cytrus.audioStretching"]);
    Settings::values.output_type.SetValue((AudioCore::SinkType)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioOutputDevice"]] unsignedIntValue]);
    Settings::values.input_type.SetValue((AudioCore::InputType)[[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.audioInputDevice"]] unsignedIntValue]);
    
    Settings::values.custom_layout.SetValue([defaults boolForKey:@"cytrus.useCustomLayout"]);
    Settings::values.custom_top_left.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopLeft"]] unsignedIntValue]);
    Settings::values.custom_top_top.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopTop"]] unsignedIntValue]);
    Settings::values.custom_top_right.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopRight"]] unsignedIntValue]);
    Settings::values.custom_top_bottom.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutTopBottom"]] unsignedIntValue]);
    Settings::values.custom_bottom_left.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomLeft"]] unsignedIntValue]);
    Settings::values.custom_bottom_top.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomTop"]] unsignedIntValue]);
    Settings::values.custom_bottom_right.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomRight"]] unsignedIntValue]);
    Settings::values.custom_bottom_bottom.SetValue([[NSNumber numberWithInteger:[defaults integerForKey:@"cytrus.customLayoutBottomBottom"]] unsignedIntValue]);
    
    Core::System::GetInstance().ApplySettings();
    Settings::LogSettings();
}

-(void) orientationChanged:(UIInterfaceOrientation)orientation mtkView:(MTKView *)mtkView {
    _mtkView = mtkView;
    window->OrientationChanged(orientation, (__bridge CA::MetalLayer*)_mtkView.layer);
    Core::System::GetInstance().GPU().Renderer().NotifySurfaceChanged();
}

-(void) touchBeganAtPoint:(CGPoint)point {
    window->TouchPressed(point.x, point.y);
    
    // float h_ratio, w_ratio;
    // h_ratio = window->GetFramebufferLayout().height / (_mtkView.frame.size.height * [[UIScreen mainScreen] nativeScale]);
    // w_ratio = window->GetFramebufferLayout().width / (_mtkView.frame.size.width * [[UIScreen mainScreen] nativeScale]);
    
    // window->TouchPressed((point.x) * [[UIScreen mainScreen] nativeScale] * w_ratio, ((point.y) * [[UIScreen mainScreen] nativeScale] * h_ratio));
}

-(void) touchEnded {
    window->TouchReleased();
}

-(void) touchMovedAtPoint:(CGPoint)point {
    window->TouchMoved(point.x, point.y);
    
    // float h_ratio, w_ratio;
    // h_ratio = window->GetFramebufferLayout().height / (_mtkView.frame.size.height * [[UIScreen mainScreen] nativeScale]);
    // w_ratio = window->GetFramebufferLayout().width / (_mtkView.frame.size.width * [[UIScreen mainScreen] nativeScale]);
    
    // window->TouchMoved((point.x) * [[UIScreen mainScreen] nativeScale] * w_ratio, ((point.y) * [[UIScreen mainScreen] nativeScale] * h_ratio));
}

-(void) thumbstickMoved:(VirtualControllerAnalogType)analog x:(CGFloat)x y:(CGFloat)y {
    InputManager::AnalogHandler()->MoveJoystick([[NSNumber numberWithUnsignedInteger:analog] intValue], x, y);
}

-(void) virtualControllerButtonDown:(VirtualControllerButtonType)button {
    InputManager::ButtonHandler()->PressKey([[NSNumber numberWithUnsignedInteger:button] intValue]);
}

-(void) virtualControllerButtonUp:(VirtualControllerButtonType)button {
    InputManager::ButtonHandler()->ReleaseKey([[NSNumber numberWithUnsignedInteger:button] intValue]);
}

-(BOOL) isPaused {
    return pause_emulation;
}

-(void) pausePlay:(BOOL)pausePlay {
    if (pausePlay) { // play
        pause_emulation = false;
        running_cv.notify_all();
    } else
        pause_emulation = true;
}

-(void) stop {
    stop_run = true;
    pause_emulation = false;
    window->StopPresenting();
    running_cv.notify_all();
}

-(InstallStatus) importGame:(NSURL *)url {
    Service::AM::InstallStatus result = Service::AM::InstallCIA([url.path UTF8String], [](std::size_t total_bytes_read, std::size_t file_size) {});
    return (InstallStatus)result;
}

-(NSMutableArray<NSURL *> *) installedGamePaths {
    NSMutableArray<NSURL *> *paths = @[].mutableCopy;
    
    const FileUtil::DirectoryEntryCallable ScanDir = [&paths, &ScanDir](u64*, const std::string& directory, const std::string& virtual_name) {
        std::string path = directory + virtual_name;
        if (FileUtil::IsDirectory(path)) {
            path += '/';
            FileUtil::ForeachDirectoryEntry(nullptr, path, ScanDir);
        } else {
            if (!FileUtil::Exists(path))
                return false;
            auto loader = Loader::GetLoader(path);
            if (loader) {
                bool executable{};
                const Loader::ResultStatus result = loader->IsExecutable(executable);
                if (Loader::ResultStatus::Success == result && executable) {
                    [paths addObject:[NSURL fileURLWithPath:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]]];
                }
            }
        }
        return true;
    };
    
    ScanDir(nullptr, "", FileUtil::GetUserPath(FileUtil::UserPath::SDMCDir) + "Nintendo " "3DS/00000000000000000000000000000000/" "00000000000000000000000000000000/title/00040000");
    
    return paths;
}

-(NSMutableArray<NSURL *> *) systemGamePaths {
    NSMutableArray<NSURL *> *paths = @[].mutableCopy;
    
    const FileUtil::DirectoryEntryCallable ScanDir = [&paths, &ScanDir](u64*, const std::string& directory, const std::string& virtual_name) {
        std::string path = directory + virtual_name;
        if (FileUtil::IsDirectory(path)) {
            path += '/';
            FileUtil::ForeachDirectoryEntry(nullptr, path, ScanDir);
        } else {
            if (!FileUtil::Exists(path))
                return false;
            auto loader = Loader::GetLoader(path);
            if (loader) {
                bool executable{};
                const Loader::ResultStatus result = loader->IsExecutable(executable);
                if (Loader::ResultStatus::Success == result && executable) {
                    [paths addObject:[NSURL fileURLWithPath:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]]];
                }
            }
        }
        return true;
    };
    
    ScanDir(nullptr, "", FileUtil::GetUserPath(FileUtil::UserPath::NANDDir) + "00000000000000000000000000000000/title/00040030");
    
    return paths;
}
@end
