//
//  CytrusObjC.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

#import "Configuration.h"
#import "CytrusObjC.h"
#import "EmulationWindow_Vulkan.h"

#include <Metal/Metal.hpp>

#include "InputManager.h"

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

@implementation CytrusGameInformation
-(CytrusGameInformation *) initWithURL:(NSURL *)url {
    if (self = [super init]) {
        using namespace InformationForGame;
        
        const auto data = GetSMDHData([url.path UTF8String]);
        const auto publisher = Publisher(data);
        const auto regions = Regions(data);
        const auto title = Title(data);
        
        self.icon = [NSData dataWithBytes:InformationForGame::Icon(data).data() length:48 * 48 * sizeof(uint16_t)];
        self.company = [NSString stringWithCharacters:(const unichar*)publisher.c_str() length:publisher.length()];
        self.regions = [NSString stringWithCString:regions.c_str() encoding:NSUTF8StringEncoding];
        self.title = [NSString stringWithCharacters:(const unichar*)title.c_str() length:title.length()];
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
    
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.cpuClockPercentage"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([defaults boolForKey:@"cytrus.useNew3DS"]);
    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.useLLEApplets"]);
    
    Settings::values.region_value.SetValue([[NSNumber numberWithInteger:[defaults doubleForKey:@"cytrus.regionValue"]] unsignedIntValue]);
    
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
    
    u64 program_id{};
    FileUtil::SetCurrentRomPath([url.path UTF8String]);
    auto app_loader = Loader::GetLoader([url.path UTF8String]);
    if (app_loader) {
        app_loader->ReadProgramId(program_id);
        system.RegisterAppLoaderEarly(app_loader);
    }
    
    system.ApplySettings();
    Settings::LogSettings();
    
    Frontend::RegisterDefaultApplets(system);
    // system.RegisterMiiSelector(std::make_shared<MiiSelector::AndroidMiiSelector>());
    // system.RegisterSoftwareKeyboard(std::make_shared<SoftwareKeyboard::Keyboard>());
    
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
}

-(BOOL) running {
    return Core::System::GetInstance().IsPoweredOn();
}

-(BOOL) stopped {
    return stop_run && !pause_emulation;
}

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(MTKView *)metalView {
    if (!Core::System::GetInstance().IsPoweredOn())
        return;
    
    top_window->SizeChanged(metalView.bounds.size);
    
    top_window->OrientationChanged(orientation, (__bridge CA::MetalLayer*)metalView.layer);
    Core::System::GetInstance().GPU().Renderer().NotifySurfaceChanged();
}
@end
