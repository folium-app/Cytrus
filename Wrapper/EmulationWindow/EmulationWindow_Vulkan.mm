//
//  EmulationWindow_Vulkan.mm
//  Limon
//
//  Created by Jarrod Norwell on 1/20/24.
//

#import <UIKit/UIKit.h>

#include "EmulationWindow_Vulkan.h"
#include "GraphicsContext_Apple.h"

EmulationWindow_Vulkan::EmulationWindow_Vulkan(CA::MetalLayer* surface, std::shared_ptr<Common::DynamicLibrary> driver_library, bool is_secondary, CGSize size) : EmulationWindow_Apple(surface, is_secondary, size), surface{surface}, driver_library(driver_library) {
    CreateWindowSurface();
    
    if (core_context = CreateSharedContext(); !core_context)
        return;
    
    OnFramebufferSizeChanged();
};


void EmulationWindow_Vulkan::PollEvents() {};


void EmulationWindow_Vulkan::OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface) {
    is_portrait = orientation == UIInterfaceOrientationPortrait;
    
    OnSurfaceChanged(surface);
    OnFramebufferSizeChanged();
};


std::unique_ptr<Frontend::GraphicsContext> EmulationWindow_Vulkan::CreateSharedContext() const {
    return std::make_unique<GraphicsContext_Apple>(driver_library);
};


bool EmulationWindow_Vulkan::CreateWindowSurface() {
    if (!host_window)
        return true;
    
    window_info.render_surface = host_window;
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface_scale = [[UIScreen mainScreen] nativeScale];
    
    return true;
};
