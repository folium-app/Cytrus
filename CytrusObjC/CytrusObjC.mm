//
//  CytrusObjC.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

#import <TargetConditionals.h>

#import "Configuration.h"
#import "CytrusObjC.h"
#import "EmulationWindow_Vulkan.h"

#include <Metal/Metal.hpp>

#import "CameraFactory.h"
#import "InputManager.h"


// MARK: Keyboard

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
    
    isReady = FALSE;
    
    return std::make_pair([this->keyboardText UTF8String], this->buttonPressed);
}
}

// MARK: Keyboard

std::unique_ptr<EmulationWindow_Vulkan> top_window;
std::shared_ptr<Common::DynamicLibrary> library;

static void TryShutdown() {
    if (!top_window)
        return;
    
    top_window->DoneCurrent();
    Core::System::GetInstance().Shutdown();
    top_window.reset();
    InputManager::Shutdown();
};

@implementation CoreVersion
-(CoreVersion *) initWithCoreVersion:(uint32_t)coreVersion {
    if (self = [super init]) {
        Kernel::CoreVersion version = Kernel::CoreVersion(coreVersion);
        
        self.major = version.major;
        self.minor = version.minor;
        self.revision = version.revision;
    } return self;
}
@end

@implementation CytrusGameInformation
-(CytrusGameInformation *) initWithURL:(NSURL *)url {
    if (self = [super init]) {
        using namespace InformationForGame;
        
        const auto data = GetSMDHData([url.path UTF8String]);
        const auto publisher = Publisher(data);
        const auto regions = Regions(data);
        const auto title = Title(data);
        
        u64 program_id{0};
        auto app_loader = Loader::GetLoader([url.path UTF8String]);
        if (app_loader) {
            app_loader->ReadProgramId(program_id);
        }
        
        uint32_t defaultCoreVersion = (1 << 24) | (0 << 16) | (1 << 8);
        
        self.coreVersion = [[CoreVersion alloc] initWithCoreVersion:defaultCoreVersion];
        self.kernelMemoryMode = (KernelMemoryMode)(app_loader->LoadKernelMemoryMode().first || 0);
        self.new3DSKernelMemoryMode = (New3DSKernelMemoryMode)app_loader->LoadNew3dsHwCapabilities().first->memory_mode;
        
        self.identifier = program_id;
        if (Icon(data).empty())
            self.icon = NULL;
        else
            self.icon = [NSData dataWithBytes:InformationForGame::Icon(data).data() length:48 * 48 * sizeof(uint16_t)];
        self.publisher = [NSString stringWithCharacters:(const unichar*)publisher.c_str() length:publisher.length()];
        self.regions = [NSString stringWithCString:regions.c_str() encoding:NSUTF8StringEncoding];
        self.title = [NSString stringWithCharacters:(const unichar*)title.c_str() length:title.length()];
    } return self;
}
@end

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

-(CytrusGameInformation *) informationForGameAt:(NSURL *)url {
    return [[CytrusGameInformation alloc] initWithURL:url];
}

-(void) allocateVulkanLibrary {
    library = std::make_shared<Common::DynamicLibrary>(dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW));
}

-(void) deallocateVulkanLibrary {
    library.reset();
}

-(void) allocateMetalLayer:(CAMetalLayer*)layer withSize:(CGSize)size isSecondary:(BOOL)secondary {
    top_window = std::make_unique<EmulationWindow_Vulkan>((__bridge CA::MetalLayer*)layer, library, secondary, size);
}

-(void) deallocateMetalLayers {
    top_window.reset();
}

-(void) insertCartridgeAndBoot:(NSURL *)url {
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
            
            top_window->PollEvents();
        }
    }
}

-(ImportResultStatus) importGameAt:(NSURL *)url {
    return (ImportResultStatus)Service::AM::InstallCIA([url.path UTF8String], [](std::size_t total_bytes_read, std::size_t file_size) {});
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

-(void) virtualControllerButtonDown:(VirtualControllerButtonType)button {
    InputManager::ButtonHandler()->PressKey([[NSNumber numberWithUnsignedInteger:button] intValue]);
}

-(void) virtualControllerButtonUp:(VirtualControllerButtonType)button {
    InputManager::ButtonHandler()->ReleaseKey([[NSNumber numberWithUnsignedInteger:button] intValue]);
}

-(void) thumbstickMoved:(VirtualControllerAnalogType)analog x:(CGFloat)x y:(CGFloat)y {
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

-(void) loadState {
    Core::System::GetInstance().SendSignal(Core::System::Signal::Load, 0);
}

-(void) saveState {
    Core::System::GetInstance().SendSignal(Core::System::Signal::Save, 0);
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
