//
//  CytrusEmulator.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 2/7/2025.
//

#import "Configuration.h"
#import "CytrusEmulator.h"
#import "EmulationWindow_Vulkan.h"
#import "CameraFactory.h"
#import "InputManager.h"
#import "SoftwareKeyboard.h"

#import "Cytrus-Swift.h"

#include <Metal.hpp>

#import <SDL3/SDL_main.h>

std::unique_ptr<EmulationWindow_Vulkan> top_window, bottom_window;
std::shared_ptr<Common::DynamicLibrary> library;
std::shared_ptr<Service::CFG::Module> cfg;

CA::MetalLayer* top_layer;
CA::MetalLayer* bottom_layer;
CGSize top_size, bottom_size;

static void TryShutdown() {
    if (!top_window)
        return;
    
    top_window->DoneCurrent();
    Core::System::GetInstance().Shutdown();
    top_window.reset();
    InputManager::Shutdown();
};

@implementation CytrusEmulator
-(CytrusEmulator *) init {
    if (self = [super init]) {
        Common::Log::Initialize();
        Common::Log::SetColorConsoleBackendEnabled(false);
        Common::Log::Start();
        
        Common::Log::Filter filter;
        filter.ParseFilterString(Settings::values.log_filter.GetValue());
        Common::Log::SetGlobalFilter(filter);
        
        pause_emulation.store(false);
        stop_run.store(false);
        
        SDL_SetMainReady();
    } return self;
}

+(CytrusEmulator *) sharedInstance {
    static CytrusEmulator *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) allocate {
    library = std::make_shared<Common::DynamicLibrary>(dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW));
}

-(void) deallocate {
    library.reset();
}

-(void) top:(CAMetalLayer *)layer size:(CGSize)size {
    top_layer = (__bridge CA::MetalLayer*)layer;
    top_size = size;
}

-(void) bottom:(CAMetalLayer *)layer size:(CGSize)size {
    bottom_layer = (__bridge CA::MetalLayer*)layer;
    bottom_size = size;
}

-(void) deinitialize {
    top_window.reset();
    bottom_window.reset();
}

-(void) insert:(NSURL *)url withCallback:(void (^)())callback {
    std::scoped_lock lock(running_mutex);
        
    Core::System& system{Core::System::GetInstance()};
        
    Configuration config{};
    
    [self updateSettings];
    
    if (bottom_layer) {
        Settings::values.aspect_ratio.SetValue(Settings::AspectRatio::Stretch);
        Settings::values.layout_option.SetValue(Settings::LayoutOption::SeparateWindows);
    }
    top_window = std::make_unique<EmulationWindow_Vulkan>(top_layer, false, library, top_size);
    if (bottom_layer)
        bottom_window = std::make_unique<EmulationWindow_Vulkan>(bottom_layer, true, library, bottom_size);
    
    u64 program_id{};
    FileUtil::SetCurrentRomPath([url.path UTF8String]);
    auto app_loader = Loader::GetLoader([url.path UTF8String]);
    if (app_loader) {
        app_loader->ReadProgramId(program_id);
    }
    
    system.ApplySettings();
    Settings::LogSettings();
    
    auto frontCamera = std::make_unique<Camera::iOSFrontCameraFactory>();
    auto leftRearCamera = std::make_unique<Camera::iOSLeftRearCameraFactory>();
    auto rightRearCamera = std::make_unique<Camera::iOSRightRearCameraFactory>();
    Camera::RegisterFactory("av_front", std::move(frontCamera));
    Camera::RegisterFactory("av_left_rear", std::move(leftRearCamera));
    Camera::RegisterFactory("av_right_rear", std::move(rightRearCamera));
    
    Frontend::RegisterDefaultApplets(system);
    // system.RegisterMiiSelector(std::make_shared<MiiSelector::AndroidMiiSelector>());
#if defined(TARGET_OS_IPHONE)
    system.RegisterSoftwareKeyboard(std::make_shared<SoftwareKeyboard::Keyboard>());
#endif
    
    InputCommon::Init();
    InputManager::Init();
    Network::Init();
    
    if (auto bottom = bottom_window.get(); bottom) {
        void(system.Load(*top_window, [url.path UTF8String], bottom));
    } else
        void(system.Load(*top_window, [url.path UTF8String]));
    
    stop_run.store(false);
    pause_emulation.store(false);
    
    if (_disk_cache_callback)
        _disk_cache_callback(static_cast<uint8_t>(VideoCore::LoadCallbackStage::Prepare), 0, 0);
    
    std::unique_ptr<Frontend::GraphicsContext> cpu_context;
    system.GPU().Renderer().Rasterizer()->LoadDefaultDiskResources(stop_run, [&](VideoCore::LoadCallbackStage stage, std::size_t progress, std::size_t maximum) {
        if (_disk_cache_callback)
            _disk_cache_callback(static_cast<uint8_t>(stage), progress, maximum);
    });
    
    if (_disk_cache_callback)
        _disk_cache_callback(static_cast<uint8_t>(VideoCore::LoadCallbackStage::Complete), 0, 0);
    
    SCOPE_EXIT({
        TryShutdown();
    });
    
    auto status_to_str = [](HW::UniqueData::SecureDataLoadStatus status) {
        switch (status) {
            case HW::UniqueData::SecureDataLoadStatus::Loaded:
                return "Status: Loaded";
            case HW::UniqueData::SecureDataLoadStatus::InvalidSignature:
                return "Status: Loaded (Invalid Signature)";
            case HW::UniqueData::SecureDataLoadStatus::RegionChanged:
                return "Status: Loaded (Region Changed)";
            case HW::UniqueData::SecureDataLoadStatus::NotFound:
                return "Status: Not Found";
            case HW::UniqueData::SecureDataLoadStatus::Invalid:
                return "Status: Invalid";
            case HW::UniqueData::SecureDataLoadStatus::IOError:
                return "Status: IO Error";
            default:
                return "";
        }
    };
    
    NSLog(@"LocalFriendCodeSeedB: %s", status_to_str(HW::UniqueData::LoadLocalFriendCodeSeedB()));
    NSLog(@"Movable: %s", status_to_str(HW::UniqueData::LoadMovable()));
    NSLog(@"OTP: %s", status_to_str(HW::UniqueData::LoadOTP()));
    NSLog(@"SecureInfoA: %s", status_to_str(HW::UniqueData::LoadSecureInfoA()));
    NSLog(@"IsFullConsoleLinked: %@", HW::UniqueData::IsFullConsoleLinked() ? @"YES" : @"NO");
    
    static dispatch_once_t onceToken;
    while (!stop_run.load()) {
        if (!pause_emulation.load()) {
            void(system.RunLoop());
        } else {
            const float volume = Settings::values.volume.GetValue();
            
            SCOPE_EXIT({
                Settings::values.volume.SetValue(volume);
            });
            
            Settings::values.volume.SetValue(0);

            std::unique_lock pause_lock{paused_mutex};
            running_cv.wait(pause_lock, [&] {
                return !pause_emulation.load() || stop_run.load();
            });
            
            bottom_window->PollEvents(); // noop
        }
        
        dispatch_once(&onceToken, ^{
            callback();
        });
    }
    
    Network::Shutdown();
    InputManager::Shutdown();
}

-(BOOL) installCIA:(NSURL *)url withCallback:(void (^)())callback {
    using namespace Service::AM;
    
    bool is_compressed{false};
    if (CheckCIAToInstall(url.path.UTF8String, is_compressed, true) == InstallStatus::Success)
        return InstallCIA(std::string{[url.path UTF8String]}) == InstallStatus::Success;
    return FALSE;
}

-(NSURL *) bootHome:(NSInteger)region {
    auto path = Core::GetHomeMenuNcchPath([[NSNumber numberWithInteger:region] intValue]);
    return [NSURL URLWithString:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]];
}

-(void) touchBeganAtPoint:(CGPoint)point {
    if (![self running])
        return;
    
    float h_ratio, w_ratio;
    if (auto bottom = bottom_window.get()) {
        h_ratio = bottom->GetFramebufferLayout().height / (bottom->window_height * [[UIScreen mainScreen] nativeScale]);
        w_ratio = bottom->GetFramebufferLayout().width / (bottom->window_width * [[UIScreen mainScreen] nativeScale]);
        
        bottom->TouchPressed(point.x * [[UIScreen mainScreen] nativeScale] * w_ratio, point.y * [[UIScreen mainScreen] nativeScale] * h_ratio);
    } else {
        h_ratio = top_window->GetFramebufferLayout().height / (top_window->window_height * [[UIScreen mainScreen] nativeScale]);
        w_ratio = top_window->GetFramebufferLayout().width / (top_window->window_width * [[UIScreen mainScreen] nativeScale]);
        
        top_window->TouchPressed(point.x * [[UIScreen mainScreen] nativeScale] * w_ratio, point.y * [[UIScreen mainScreen] nativeScale] * h_ratio);
    }
}

-(void) touchEnded {
    if (![self running])
        return;
    
    if (auto bottom = bottom_window.get()) {
        bottom->TouchReleased();
    } else {
        top_window->TouchReleased();
    }
}

-(void) touchMovedAtPoint:(CGPoint)point {
    if (![self running])
        return;
    
    float h_ratio, w_ratio;
    if (auto bottom = bottom_window.get()) {
        h_ratio = bottom->GetFramebufferLayout().height / (bottom->window_height * [[UIScreen mainScreen] nativeScale]);
        w_ratio = bottom->GetFramebufferLayout().width / (bottom->window_width * [[UIScreen mainScreen] nativeScale]);
        
        bottom->TouchMoved(point.x * [[UIScreen mainScreen] nativeScale] * w_ratio, point.y * [[UIScreen mainScreen] nativeScale] * h_ratio);
    } else {
        h_ratio = top_window->GetFramebufferLayout().height / (top_window->window_height * [[UIScreen mainScreen] nativeScale]);
        w_ratio = top_window->GetFramebufferLayout().width / (top_window->window_width * [[UIScreen mainScreen] nativeScale]);
        
        top_window->TouchMoved(point.x * [[UIScreen mainScreen] nativeScale] * w_ratio, point.y * [[UIScreen mainScreen] nativeScale] * h_ratio);
    }
}

-(BOOL) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed {
    if (![self running])
        return FALSE;
    
    auto handler = InputManager::ButtonHandler();
    
    auto key = [[NSNumber numberWithUnsignedInt:button] intValue];
    BOOL result;
    if (pressed)
        result = handler->PressKey(key);
    else
        result = handler->ReleaseKey(key);
    return result;
}

-(void) thumbstickMoved:(uint32_t)analog x:(CGFloat)x y:(CGFloat)y {
    if (![self running])
        return;
    
    InputManager::AnalogHandler()->MoveJoystick([[NSNumber numberWithUnsignedInteger:analog] intValue], x, y);
}

-(BOOL) isPaused {
    return pause_emulation.load();
}

-(void) pause:(BOOL)pause {
    pause_emulation.store(pause);
    if (!pause_emulation.load())
        running_cv.notify_all();
}

-(void) stop {
    stop_run.store(true);
    pause_emulation.store(false);
    top_window->StopPresenting();
    bottom_window->StopPresenting();
    running_cv.notify_all();
    
    Core::System::GetInstance().RequestShutdown();
}

-(BOOL) running {
    return Core::System::GetInstance().IsPoweredOn();
}

-(BOOL) stopped {
    return stop_run.load() && !pause_emulation.load();
}

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(UIView *)metalView secondary:(BOOL)secondary {
    if (auto bottom = bottom_window.get(); secondary) {
        bottom_layer = (__bridge CA::MetalLayer*)metalView.layer;
        bottom_size = metalView.frame.size;
        
        bottom->SizeChanged(metalView.frame.size);
        bottom->OrientationChanged(orientation, (__bridge CA::MetalLayer*)metalView.layer);
    } else {
        top_layer = (__bridge CA::MetalLayer*)metalView.layer;
        top_size = metalView.frame.size;
        
        top_window->SizeChanged(metalView.frame.size);
        top_window->OrientationChanged(orientation, (__bridge CA::MetalLayer*)metalView.layer);
    }
    
    Core::System::GetInstance().GPU().Renderer().NotifySurfaceChanged(false);
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

-(void) updateSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    bool (^boolean)(NSString *) = ^bool(NSString *key) { return [defaults boolForKey:key]; };
    float (^_float)(NSString *) = ^float(NSString *key) { return [[NSNumber numberWithDouble:[defaults doubleForKey:key]] floatValue]; };
    s32 (^signed32)(NSString *) = ^s32(NSString *key) { return [[NSNumber numberWithDouble:[defaults doubleForKey:key]] intValue]; };
    u16 (^unsigned16)(NSString *) = ^u16(NSString *key) { return [[NSNumber numberWithDouble:[defaults doubleForKey:key]] intValue]; };
    u32 (^unsigned32)(NSString *) = ^u32(NSString *key) { return [[NSNumber numberWithDouble:[defaults doubleForKey:key]] intValue]; };
    std::string (^string)(NSString *) = ^std::string(NSString *key) { return std::string{[[defaults stringForKey:key] UTF8String]}; };
    
    Settings::values.camera_name[Service::CAM::InnerCamera] = "av_front";
    Settings::values.camera_name[Service::CAM::OuterLeftCamera] = "av_left_rear";
    Settings::values.camera_name[Service::CAM::OuterRightCamera] = "av_right_rear";
    
    // Core
    if (@available(iOS 26, *)) {
        Settings::values.use_cpu_jit.SetValue(false);
    } else {
        Settings::values.use_cpu_jit.SetValue(boolean(@"cytrus.v1.35.cpuJIT"));
    }
    Settings::values.cpu_clock_percentage.SetValue(signed32(@"cytrus.v1.35.cpuClockPercentage"));
    Settings::values.is_new_3ds.SetValue(boolean(@"cytrus.v1.35.new3DS"));
    Settings::values.lle_applets.SetValue(boolean(@"cytrus.v1.35.lleApplets"));
    Settings::values.deterministic_async_operations.SetValue(boolean(@"cytrus.v1.35.deterministicAsyncOperations"));
    Settings::values.enable_required_online_lle_modules.SetValue(boolean(@"cytrus.v1.35.enableRequiredOnlineLLEModules"));
    // Data Storage
    Settings::values.compress_cia_installs.SetValue(boolean(@"cytrus.v1.35.compressCIAInstalls"));
    // System
    Settings::values.region_value.SetValue(signed32(@"cytrus.v1.35.regionValue"));
    Settings::values.plugin_loader_enabled.SetValue(boolean(@"cytrus.v1.35.pluginLoader"));
    Settings::values.allow_plugin_loader.SetValue(boolean(@"cytrus.v1.35.allowPluginLoader"));
    Settings::values.steps_per_hour.SetValue(unsigned16(@"cytrus.v1.35.stepsPerHour"));
    // Renderer
    Settings::values.spirv_shader_gen.SetValue(boolean(@"cytrus.v1.35.spirvShaderGeneration"));
    Settings::values.disable_spirv_optimizer.SetValue(boolean(@"cytrus.v1.35.disableSpirvOptimizer"));
    Settings::values.async_shader_compilation.SetValue(boolean(@"cytrus.v1.35.useAsyncShaderCompilation"));
    Settings::values.async_presentation.SetValue(boolean(@"cytrus.v1.35.useAsyncPresentation"));
    Settings::values.use_hw_shader.SetValue(boolean(@"cytrus.v1.35.useHardwareShaders"));
    Settings::values.use_disk_shader_cache.SetValue(boolean(@"cytrus.v1.35.useDiskShaderCache"));
    Settings::values.shaders_accurate_mul.SetValue(boolean(@"cytrus.v1.35.useShadersAccurateMul"));
    Settings::values.use_vsync_new.SetValue(boolean(@"cytrus.v1.35.useNewVSync"));
    if (@available(iOS 26, *)) {
        Settings::values.use_shader_jit.SetValue(false);
    } else {
        Settings::values.use_shader_jit.SetValue(boolean(@"cytrus.v1.35.useShaderJIT"));
    }
    Settings::values.resolution_factor.SetValue(unsigned32(@"cytrus.v1.35.resolutionFactor"));
    Settings::values.texture_filter.SetValue(static_cast<Settings::TextureFilter>(unsigned32(@"cytrus.v1.35.textureFilter")));
    Settings::values.texture_sampling.SetValue(static_cast<Settings::TextureSampling>(unsigned32(@"cytrus.v1.35.textureSampling")));
    Settings::values.delay_game_render_thread_us.SetValue(unsigned16(@"cytrus.v1.35.delayGameRenderThreadUS"));
    if (bottom_layer)
        Settings::values.layout_option.SetValue(Settings::LayoutOption::SeparateWindows);
    else
        Settings::values.layout_option.SetValue(static_cast<Settings::LayoutOption>(unsigned32(@"cytrus.v1.35.layoutOption")));
    Settings::values.custom_top_x.SetValue(unsigned16(@"cytrus.v1.35.customTopX"));
    Settings::values.custom_top_y.SetValue(unsigned16(@"cytrus.v1.35.customTopY"));
    Settings::values.custom_top_width.SetValue(unsigned16(@"cytrus.v1.35.customTopWidth"));
    Settings::values.custom_top_height.SetValue(unsigned16(@"cytrus.v1.35.customTopHeight"));
    Settings::values.custom_bottom_x.SetValue(unsigned16(@"cytrus.v1.35.customBottomX"));
    Settings::values.custom_bottom_y.SetValue(unsigned16(@"cytrus.v1.35.customBottomY"));
    Settings::values.custom_bottom_width.SetValue(unsigned16(@"cytrus.v1.35.customBottomWidth"));
    Settings::values.custom_bottom_height.SetValue(unsigned16(@"cytrus.v1.35.customBottomHeight"));
    Settings::values.custom_second_layer_opacity.SetValue(unsigned16(@"cytrus.v1.35.customSecondLayerOpacity"));
    Settings::values.aspect_ratio.SetValue(static_cast<Settings::AspectRatio>(unsigned32(@"cytrus.v1.35.aspectRatio")));
    Settings::values.render_3d.SetValue(static_cast<Settings::StereoRenderOption>(unsigned32(@"cytrus.v1.35.render3D")));
    Settings::values.factor_3d.SetValue(unsigned32(@"cytrus.v1.35.factor3D"));
    Settings::values.mono_render_option.SetValue(static_cast<Settings::MonoRenderOption>(unsigned32(@"cytrus.v1.35.monoRender")));
    Settings::values.filter_mode.SetValue(boolean(@"cytrus.v1.35.filterMode"));
    Settings::values.pp_shader_name.SetValue(string(@"cytrus.v1.35.ppShaderName"));
    Settings::values.anaglyph_shader_name.SetValue(string(@"cytrus.v1.35.anaglyphShaderName"));
    Settings::values.dump_textures.SetValue(boolean(@"cytrus.v1.35.dumpTextures"));
    Settings::values.custom_textures.SetValue(boolean(@"cytrus.v1.35.customTextures"));
    Settings::values.preload_textures.SetValue(boolean(@"cytrus.v1.35.preloadTextures"));
    Settings::values.async_custom_loading.SetValue(boolean(@"cytrus.v1.35.asyncCustomLoading"));
    Settings::values.disable_right_eye_render.SetValue(boolean(@"cytrus.v1.35.disableRightEyeRender"));
    // Audio
    Settings::values.audio_muted = boolean(@"cytrus.v1.35.audioMuted");
    Settings::values.audio_emulation.SetValue(static_cast<Settings::AudioEmulation>(unsigned32(@"cytrus.v1.35.audioEmulation")));
    Settings::values.enable_audio_stretching.SetValue(boolean(@"cytrus.v1.35.audioStretching"));
    Settings::values.enable_realtime_audio.SetValue(boolean(@"cytrus.v1.35.realtimeAudio"));
    Settings::values.volume.SetValue(_float(@"cytrus.v1.35.volume"));
    Settings::values.output_type.SetValue(static_cast<AudioCore::SinkType>(unsigned32(@"cytrus.v1.35.outputType")));
    Settings::values.input_type.SetValue(static_cast<AudioCore::InputType>(unsigned32(@"cytrus.v1.35.inputType")));
    // Miscellaneous
    std::string log_filter{"*:Info"};
    switch ([defaults integerForKey:@"cytrus.v1.35.logLevel"]) {
        case 0:
            log_filter = std::string{"*:Trace"};
            break;
        case 1:
            log_filter = std::string{"*:Debug"};
            break;
        case 2:
            log_filter = std::string{"*:Info"};
            break;
        case 3:
            log_filter = std::string{"*:Warning"};
            break;
        case 4:
            log_filter = std::string{"*:Error"};
            break;
        case 5:
            log_filter = std::string{"*:Critical"};
            break;
        default:
            break;
    }
    Settings::values.log_filter.SetValue(log_filter);
    NetSettings::values.web_api_url = string(@"cytrus.v1.35.webAPIURL");
    
    Common::Log::Filter filter;
    filter.ParseFilterString(Settings::values.log_filter.GetValue());
    Common::Log::SetGlobalFilter(filter);
    
    /*
     case systemLanguage = "cytrus.v1.35.systemLanguage"
     case username = "cytrus.v1.35.username"
     */
}

-(uint16_t) stepsPerHour {
    return Settings::values.steps_per_hour.GetValue();
}

-(void) setStepsPerHour:(uint16_t)stepsPerHour {
    Settings::values.steps_per_hour = stepsPerHour;
}

-(BOOL) loadState {
    if (![self running])
        return FALSE;
    
    return Core::System::GetInstance().SendSignal(Core::System::Signal::Load, 0);
}

-(BOOL) saveState {
    if (![self running])
        return FALSE;
    
    return Core::System::GetInstance().SendSignal(Core::System::Signal::Save, 0);
}

-(BOOL) stateExists:(uint64_t)identifier forSlot:(NSInteger)slot {
    auto path = Core::GetSaveStatePath(identifier, 0, [[NSNumber numberWithInteger:slot] intValue]);
    return [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]];
}

-(void) load:(NSInteger)slot {
    if (![self running])
        return;
    
    Core::System::GetInstance().SendSignal(Core::System::Signal::Load, [[NSNumber numberWithInteger:slot] intValue]);
}

-(void) save:(NSInteger)slot {
    if (![self running])
        return;
    
    Core::System::GetInstance().SendSignal(Core::System::Signal::Save, [[NSNumber numberWithInteger:slot] intValue]);
}

-(BOOL) insertAmiibo:(NSURL *)url {
    if (![self running])
        return FALSE;
    
    Service::SM::ServiceManager& sm = Core::System::GetInstance().ServiceManager();
    auto nfc = sm.GetService<Service::NFC::Module::Interface>("nfc:u");
    if (!nfc)
        return FALSE;
    
    std::scoped_lock lock{Core::System::GetInstance().Kernel().GetHLELock()};
    return nfc->LoadAmiibo([url.path UTF8String]);
}

-(void) removeAbiibo {
    if (![self running])
        return;
    
    Service::SM::ServiceManager& sm = Core::System::GetInstance().ServiceManager();
    auto nfc = sm.GetService<Service::NFC::Module::Interface>("nfc:u");
    if (!nfc)
        return;
    
    std::scoped_lock lock{Core::System::GetInstance().Kernel().GetHLELock()};
    nfc->RemoveAmiibo();
}

-(void) loadConfig {
    cfg = Service::CFG::GetModule(Core::System::GetInstance());
}

-(int) getSystemLanguage {
    return cfg->GetSystemLanguage();
}

-(void) setSystemLanguage:(int)systemLanguage {
    cfg->SetSystemLanguage(static_cast<Service::CFG::SystemLanguage>(systemLanguage));
    cfg->UpdateConfigNANDSavegame();
}

-(NSString *) getUsername {
    auto username = Common::UTF16ToUTF8(cfg->GetUsername());
    return [NSString stringWithCString:username.c_str() encoding:NSUTF8StringEncoding];
}

-(void) setUsername:(NSString *)username {
    cfg->SetUsername(Common::UTF8ToUTF16([username UTF8String]));
    cfg->UpdateConfigNANDSavegame();
}

-(NSArray *) saveStates:(uint64_t)identifier {
    NSString *(^nsString)(std::string) = ^NSString *(std::string string) {
        return [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
    };
    
    NSMutableArray *saves = @[].mutableCopy;
    for (auto& element : Core::ListSaveStates(identifier, 0)) {
        CytrusSaveState *saveState = [[CytrusSaveState alloc] initWithSlot:element.first.slot
                                                                    status:(NSInteger)element.first.status
                                                                      time:element.first.time
                                                                      name:nsString(element.first.build_name)];
        
        if (element.second != std::nullopt && element.second.has_value())
            [saves addObjectsFromArray:@[
                [NSError errorWithDomain:@"com.antique.Folium-iOS.error" code:0 userInfo:@{
                    NSLocalizedDescriptionKey : [NSString stringWithCString:element.second->c_str() encoding:NSUTF8StringEncoding]
                }], saveState]];
        else
            [saves addObject:saveState];
    }
    return saves;
}

-(NSString *) saveStatePath:(uint64_t)identifier slot:(NSInteger)slot {
    return [NSString stringWithCString:Core::GetSaveStatePath(identifier, 0, [[NSNumber numberWithInteger:slot] intValue]).c_str() encoding:NSUTF8StringEncoding];
}
@end
