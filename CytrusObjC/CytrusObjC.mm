//
//  CytrusObjC.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//
#import "Configuration.h"
#import "CytrusObjC.h"
#import "EmulationWindow_Vulkan.h"
#import "CameraFactory.h"
#import "InputManager.h"
#import "SoftwareKeyboard.h"

#include <Metal/Metal.hpp>

std::unique_ptr<EmulationWindow_Vulkan> top_window;
std::shared_ptr<Common::DynamicLibrary> library;
std::shared_ptr<Service::CFG::Module> cfg;

static void TryShutdown() {
    if (!top_window)
        return;
    
    top_window->DoneCurrent();
    Core::System::GetInstance().Shutdown();
    top_window.reset();
    InputManager::Shutdown();
};

@implementation SaveStateInfo
-(SaveStateInfo *) initWithSlot:(uint32_t)slot time:(uint64_t)time buildName:(NSString *)buildName status:(int)status {
    if (self = [super init]) {
        self.slot = slot;
        self.time = time;
        self.buildName = buildName;
        self.status = status;
    } return self;
}
@end

@implementation CytrusObjC
-(CytrusObjC *) init {
    if (self = [super init]) {
        Common::Log::Initialize();
        Common::Log::SetColorConsoleBackendEnabled(true);
        Common::Log::Start();
        
        Common::Log::Filter filter;
        filter.ParseFilterString(Settings::values.log_filter.GetValue());
        Common::Log::SetGlobalFilter(filter);
        
        stop_run = pause_emulation = false;
    } return self;
}

+(CytrusObjC *) sharedInstance {
    static CytrusObjC *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(GameInformation *) information:(NSURL *)url {
    return [[GameInformation alloc] initWithURL:url];
}

-(void) allocate {
    library = std::make_shared<Common::DynamicLibrary>(dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW));
}

-(void) deallocate {
    library.reset();
}

-(void) initialize:(CAMetalLayer*)layer size:(CGSize)size secondary:(BOOL)secondary {
    top_window = std::make_unique<EmulationWindow_Vulkan>((__bridge CA::MetalLayer*)layer, library, secondary, size);
}

-(void) deinitialize {
    top_window.reset();
}

-(void) insert:(NSURL *)url {
    std::scoped_lock lock(running_mutex);
        
    Core::System& system{Core::System::GetInstance()};
        
    Configuration config{};
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    Settings::values.camera_name[Service::CAM::InnerCamera] = "av_front";
    Settings::values.camera_name[Service::CAM::OuterLeftCamera] = "av_rear";
    Settings::values.camera_name[Service::CAM::OuterLeftCamera] = "av_rear";
    
    // core
    Settings::values.use_cpu_jit.SetValue([defaults boolForKey:@"cytrus.cpuJIT"]);
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.cpuClockPercentage"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([defaults boolForKey:@"cytrus.new3DS"]);
    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.lleApplets"]);
    Settings::values.region_value.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.regionValue"]] unsignedIntValue]);
    
    Settings::values.layout_option.SetValue((Settings::LayoutOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.layoutOption"]] unsignedIntValue]);
    
    // renderer
    Settings::values.custom_layout.SetValue([defaults boolForKey:@"cytrus.customLayout"]);
    Settings::values.custom_top_left.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopLeft"]] unsignedIntValue]);
    Settings::values.custom_top_top.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopTop"]] unsignedIntValue]);
    Settings::values.custom_top_right.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopRight"]] unsignedIntValue]);
    Settings::values.custom_top_bottom.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopBottom"]] unsignedIntValue]);
    Settings::values.custom_bottom_left.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomLeft"]] unsignedIntValue]);
    Settings::values.custom_bottom_top.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomTop"]] unsignedIntValue]);
    Settings::values.custom_bottom_right.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomRight"]] unsignedIntValue]);
    Settings::values.custom_bottom_bottom.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomBottom"]] unsignedIntValue]);
    Settings::values.spirv_shader_gen.SetValue([defaults boolForKey:@"cytrus.spirvShaderGeneration"]);
    Settings::values.async_shader_compilation.SetValue([defaults boolForKey:@"cytrus.useAsyncShaderCompilation"]);
    Settings::values.async_presentation.SetValue([defaults boolForKey:@"cytrus.useAsyncPresentation"]);
    Settings::values.use_hw_shader.SetValue([defaults boolForKey:@"cytrus.useHardwareShaders"]);
    Settings::values.use_disk_shader_cache.SetValue([defaults boolForKey:@"cytrus.useDiskShaderCache"]);
    Settings::values.shaders_accurate_mul.SetValue([defaults boolForKey:@"cytrus.useShadersAccurateMul"]);
    Settings::values.use_vsync_new.SetValue([defaults boolForKey:@"cytrus.useNewVSync"]);
    Settings::values.use_shader_jit.SetValue([defaults boolForKey:@"cytrus.useShaderJIT"]);
    Settings::values.resolution_factor.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.resolutionFactor"]] unsignedIntValue]);
    Settings::values.texture_filter.SetValue((Settings::TextureFilter)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.textureFilter"]] unsignedIntValue]);
    Settings::values.texture_sampling.SetValue((Settings::TextureSampling)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.textureSampling"]] unsignedIntValue]);
    Settings::values.render_3d.SetValue((Settings::StereoRenderOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.render3D"]] unsignedIntValue]);
    Settings::values.factor_3d.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.factor3D"]] unsignedIntValue]);
    Settings::values.mono_render_option.SetValue((Settings::MonoRenderOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.monoRender"]] unsignedIntValue]);
    Settings::values.preload_textures.SetValue([defaults boolForKey:@"cytrus.preloadTextures"]);
    
    // audio
    Settings::values.audio_muted = [defaults boolForKey:@"cytrus.audioMuted"];
    Settings::values.audio_emulation.SetValue((Settings::AudioEmulation)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.audioEmulation"]] unsignedIntValue]);
    Settings::values.enable_audio_stretching.SetValue([defaults boolForKey:@"cytrus.audioStretching"]);
    Settings::values.enable_realtime_audio.SetValue([defaults boolForKey:@"cytrus.realtimeAudio"]);
    Settings::values.output_type.SetValue((AudioCore::SinkType)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.outputType"]] unsignedIntValue]);
    Settings::values.input_type.SetValue((AudioCore::InputType)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.inputType"]] unsignedIntValue]);
    
    switch ([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.logLevel"]] unsignedIntValue]) {
        case 0:
            Settings::values.log_filter.SetValue("*:Trace");
            break;
        case 1:
            Settings::values.log_filter.SetValue("*:Debug");
            break;
        case 2:
            Settings::values.log_filter.SetValue("*:Info");
            break;
        case 3:
            Settings::values.log_filter.SetValue("*:Warning");
            break;
        case 4:
            Settings::values.log_filter.SetValue("*:Error");
            break;
        case 5:
            Settings::values.log_filter.SetValue("*:Critical");
            break;
        default:
            break;
    }
    
    Common::Log::Filter filter;
    filter.ParseFilterString(Settings::values.log_filter.GetValue());
    Common::Log::SetGlobalFilter(filter);
    
    NetSettings::values.web_api_url = [[defaults stringForKey:@"cytrus.webAPIURL"] UTF8String];
    
    u64 program_id{};
    FileUtil::SetCurrentRomPath([url.path UTF8String]);
    auto app_loader = Loader::GetLoader([url.path UTF8String]);
    if (app_loader) {
        app_loader->ReadProgramId(program_id);
    }
    
    system.ApplySettings();
    Settings::LogSettings();
    
    auto frontCamera = std::make_unique<Camera::iOSFrontCameraFactory>();
    auto rearCamera = std::make_unique<Camera::iOSRearCameraFactory>();
    Camera::RegisterFactory("av_front", std::move(frontCamera));
    Camera::RegisterFactory("av_rear", std::move(rearCamera));
    
    Frontend::RegisterDefaultApplets(system);
    // system.RegisterMiiSelector(std::make_shared<MiiSelector::AndroidMiiSelector>());
#if defined(TARGET_OS_IPHONE)
    system.RegisterSoftwareKeyboard(std::make_shared<SoftwareKeyboard::Keyboard>());
#endif
    
    InputManager::Init();
    
    void(system.Load(*top_window, [url.path UTF8String]));
    
    stop_run = false;
    pause_emulation = false;
    
    if (_disk_cache_callback)
        _disk_cache_callback(static_cast<uint8_t>(VideoCore::LoadCallbackStage::Prepare), 0, 0);
    
    std::unique_ptr<Frontend::GraphicsContext> cpu_context;
    system.GPU().Renderer().Rasterizer()->LoadDiskResources(stop_run, [&](VideoCore::LoadCallbackStage stage, std::size_t progress, std::size_t maximum) {
        if (_disk_cache_callback)
            _disk_cache_callback(static_cast<uint8_t>(stage), progress, maximum);
    });
    
    if (_disk_cache_callback)
        _disk_cache_callback(static_cast<uint8_t>(VideoCore::LoadCallbackStage::Complete), 0, 0);
    
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
            
            top_window->PollEvents();
        }
    }
}

-(uint32_t) import:(NSURL *)url {
    return static_cast<uint32_t>(Service::AM::InstallCIA([url.path UTF8String], [](std::size_t, std::size_t) {}));
}

-(void) touchBeganAtPoint:(CGPoint)point {
    float h_ratio, w_ratio;
    h_ratio = top_window->GetFramebufferLayout().height / (top_window->window_height * [[UIScreen mainScreen] nativeScale]);
    w_ratio = top_window->GetFramebufferLayout().width / (top_window->window_width * [[UIScreen mainScreen] nativeScale]);
    
    top_window->TouchPressed((point.x) * [[UIScreen mainScreen] nativeScale] * w_ratio, ((point.y) * [[UIScreen mainScreen] nativeScale] * h_ratio));
}

-(void) touchEnded {
    top_window->TouchReleased();
}

-(void) touchMovedAtPoint:(CGPoint)point {
    float h_ratio, w_ratio;
    h_ratio = top_window->GetFramebufferLayout().height / (top_window->window_height * [[UIScreen mainScreen] nativeScale]);
    w_ratio = top_window->GetFramebufferLayout().width / (top_window->window_width * [[UIScreen mainScreen] nativeScale]);
    
    top_window->TouchMoved((point.x) * [[UIScreen mainScreen] nativeScale] * w_ratio, ((point.y) * [[UIScreen mainScreen] nativeScale] * h_ratio));
}

-(BOOL) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed {
    auto key = [[NSNumber numberWithUnsignedInt:button] intValue];
    BOOL result;
    if (pressed)
        result = InputManager::ButtonHandler()->PressKey(key);
    else
        result = InputManager::ButtonHandler()->ReleaseKey(key);
    return result;
}

-(void) thumbstickMoved:(uint32_t)analog x:(CGFloat)x y:(CGFloat)y {
    InputManager::AnalogHandler()->MoveJoystick([[NSNumber numberWithUnsignedInteger:analog] intValue], x, y);
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
    top_window->StopPresenting();
    running_cv.notify_all();
    
    Core::System::GetInstance().RequestShutdown();
}

-(BOOL) running {
    return Core::System::GetInstance().IsPoweredOn();
}

-(BOOL) stopped {
    return stop_run && !pause_emulation;
}

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(UIView *)metalView {
    if (!Core::System::GetInstance().IsPoweredOn())
        return;
    
    top_window->SizeChanged(metalView.bounds.size);
    
    top_window->OrientationChanged(orientation, (__bridge CA::MetalLayer*)metalView.layer);
    Core::System::GetInstance().GPU().Renderer().NotifySurfaceChanged();
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
    
    // core
    Settings::values.use_cpu_jit.SetValue([defaults boolForKey:@"cytrus.cpuJIT"]);
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.cpuClockPercentage"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([defaults boolForKey:@"cytrus.new3DS"]);
    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.lleApplets"]);
    Settings::values.region_value.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.regionValue"]] unsignedIntValue]);
    
    Settings::values.layout_option.SetValue((Settings::LayoutOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.layoutOption"]] unsignedIntValue]);
    
    // renderer
    Settings::values.custom_layout.SetValue([defaults boolForKey:@"cytrus.customLayout"]);
    Settings::values.custom_top_left.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopLeft"]] unsignedIntValue]);
    Settings::values.custom_top_top.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopTop"]] unsignedIntValue]);
    Settings::values.custom_top_right.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopRight"]] unsignedIntValue]);
    Settings::values.custom_top_bottom.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customTopBottom"]] unsignedIntValue]);
    Settings::values.custom_bottom_left.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomLeft"]] unsignedIntValue]);
    Settings::values.custom_bottom_top.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomTop"]] unsignedIntValue]);
    Settings::values.custom_bottom_right.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomRight"]] unsignedIntValue]);
    Settings::values.custom_bottom_bottom.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.customBottomBottom"]] unsignedIntValue]);
    Settings::values.spirv_shader_gen.SetValue([defaults boolForKey:@"cytrus.spirvShaderGeneration"]);
    Settings::values.async_shader_compilation.SetValue([defaults boolForKey:@"cytrus.useAsyncShaderCompilation"]);
    Settings::values.async_presentation.SetValue([defaults boolForKey:@"cytrus.useAsyncPresentation"]);
    Settings::values.use_hw_shader.SetValue([defaults boolForKey:@"cytrus.useHardwareShaders"]);
    Settings::values.use_disk_shader_cache.SetValue([defaults boolForKey:@"cytrus.useDiskShaderCache"]);
    Settings::values.shaders_accurate_mul.SetValue([defaults boolForKey:@"cytrus.useShadersAccurateMul"]);
    Settings::values.use_vsync_new.SetValue([defaults boolForKey:@"cytrus.useNewVSync"]);
    Settings::values.use_shader_jit.SetValue([defaults boolForKey:@"cytrus.useShaderJIT"]);
    Settings::values.resolution_factor.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.resolutionFactor"]] unsignedIntValue]);
    Settings::values.texture_filter.SetValue((Settings::TextureFilter)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.textureFilter"]] unsignedIntValue]);
    Settings::values.texture_sampling.SetValue((Settings::TextureSampling)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.textureSampling"]] unsignedIntValue]);
    Settings::values.render_3d.SetValue((Settings::StereoRenderOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.render3D"]] unsignedIntValue]);
    Settings::values.factor_3d.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.factor3D"]] unsignedIntValue]);
    Settings::values.mono_render_option.SetValue((Settings::MonoRenderOption)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.monoRender"]] unsignedIntValue]);
    Settings::values.preload_textures.SetValue([defaults boolForKey:@"cytrus.preloadTextures"]);
    
    // audio
    Settings::values.audio_muted = [defaults boolForKey:@"cytrus.audioMuted"];
    Settings::values.audio_emulation.SetValue((Settings::AudioEmulation)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.audioEmulation"]] unsignedIntValue]);
    Settings::values.enable_audio_stretching.SetValue([defaults boolForKey:@"cytrus.audioStretching"]);
    Settings::values.enable_realtime_audio.SetValue([defaults boolForKey:@"cytrus.realtimeAudio"]);
    Settings::values.output_type.SetValue((AudioCore::SinkType)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.outputType"]] unsignedIntValue]);
    Settings::values.input_type.SetValue((AudioCore::InputType)[[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.inputType"]] unsignedIntValue]);
    
    switch ([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.logLevel"]] unsignedIntValue]) {
        case 0:
            Settings::values.log_filter.SetValue("*:Trace");
            break;
        case 1:
            Settings::values.log_filter.SetValue("*:Debug");
            break;
        case 2:
            Settings::values.log_filter.SetValue("*:Info");
            break;
        case 3:
            Settings::values.log_filter.SetValue("*:Warning");
            break;
        case 4:
            Settings::values.log_filter.SetValue("*:Error");
            break;
        case 5:
            Settings::values.log_filter.SetValue("*:Critical");
            break;
        default:
            break;
    }
    
    Common::Log::Filter filter;
    filter.ParseFilterString(Settings::values.log_filter.GetValue());
    Common::Log::SetGlobalFilter(filter);
    
    NetSettings::values.web_api_url = [[defaults stringForKey:@"cytrus.webAPIURL"] UTF8String];
}

-(uint16_t) stepsPerHour {
    return Settings::values.steps_per_hour.GetValue();
}

-(void) setStepsPerHour:(uint16_t)stepsPerHour {
    NSLog(@"%s, steps=%hu", __FUNCTION__, stepsPerHour);
    Settings::values.steps_per_hour = stepsPerHour;
}

-(BOOL) loadState {
    return Core::System::GetInstance().SendSignal(Core::System::Signal::Load, 0);
}

-(BOOL) saveState {
    return Core::System::GetInstance().SendSignal(Core::System::Signal::Save, 0);
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

-(NSArray<SaveStateInfo *> *) saveStates:(uint64_t)identifier {
    NSMutableArray<SaveStateInfo *> *saves = @[].mutableCopy;
    for (auto& state : Core::ListSaveStates(identifier, 0)) {
        [saves addObject:[[SaveStateInfo alloc] initWithSlot:state.slot
                                                        time:state.time
                                                   buildName:[NSString stringWithCString:state.build_name.c_str() encoding:NSUTF8StringEncoding]
                                                      status:(int)state.status]];
    }
    return saves;
}

-(NSString *) saveStatePath:(uint64_t)identifier {
    return [NSString stringWithCString:Core::GetSaveStatePath(identifier, 0, 0).c_str() encoding:NSUTF8StringEncoding];
}
@end
