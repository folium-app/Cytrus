//
//  EmulationWindow_Vulkan.mm
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#import "EmulationWindow_Vulkan.h"
#include "GraphicsContext_Apple.h"

#import <UIKit/UIKit.h>

#ifdef __cplusplus
#include <algorithm>
#include <array>
#include <cstdlib>
#include <string>

#include "common/logging/log.h"
#include "common/settings.h"
#include "core/frontend/emu_window.h"
#include "video_core/renderer_base.h"
#include "video_core/video_core.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#endif

EmulationWindow_Vulkan::EmulationWindow_Vulkan(CA::MetalLayer* surface, bool is_secondary, std::shared_ptr<Common::DynamicLibrary> driver_library, CGSize size) : Frontend::EmuWindow(is_secondary), host_window(surface), m_size(size), driver_library(driver_library) {
    if (Settings::values.layout_option.GetValue() == Settings::LayoutOption::SeparateWindows)
        is_portrait = false;
    else
        is_portrait = true;
    
    if (!surface)
        return;
    
    window_width = m_size.width;
    window_height = m_size.height;
    
    CreateWindowSurface();
    if (core_context = CreateSharedContext(); !core_context)
        return;
    
    OnFramebufferSizeChanged();
};

EmulationWindow_Vulkan::~EmulationWindow_Vulkan() {
    DestroyWindowSurface();
    DestroyContext();
};

void EmulationWindow_Vulkan::PollEvents() {};

void EmulationWindow_Vulkan::OnSurfaceChanged(CA::MetalLayer* surface) {
    render_window = surface;
    
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface = surface;
    window_info.render_surface_scale = [[UIScreen mainScreen] nativeScale];

    StopPresenting();
    OnFramebufferSizeChanged();
};

void EmulationWindow_Vulkan::SizeChanged(CGSize size) {
    m_size = size;
    window_width = m_size.width;
    window_height = m_size.height;
}

void EmulationWindow_Vulkan::OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface) {
    if (Settings::values.layout_option.GetValue() != Settings::LayoutOption::SeparateWindows)
        is_portrait = UIInterfaceOrientationIsPortrait(orientation);
    OnSurfaceChanged(surface);
};

void EmulationWindow_Vulkan::OnTouchEvent(int x, int y) {
    TouchPressed(static_cast<unsigned>(std::max(x, 0)), static_cast<unsigned>(std::max(y, 0)));
}

void EmulationWindow_Vulkan::OnTouchMoved(int x, int y) {
    TouchMoved(static_cast<unsigned>(std::max(x, 0)), static_cast<unsigned>(std::max(y, 0)));
}

void EmulationWindow_Vulkan::OnTouchReleased() {
    TouchReleased();
};


void EmulationWindow_Vulkan::DoneCurrent() {
    core_context->DoneCurrent();
};

void EmulationWindow_Vulkan::MakeCurrent() {
    core_context->MakeCurrent();
};


void EmulationWindow_Vulkan::StopPresenting() {};
void EmulationWindow_Vulkan::TryPresenting() {};


void EmulationWindow_Vulkan::OnFramebufferSizeChanged() {
    printf("%i, %i\n", is_portrait, is_secondary);
    
    auto bigger{window_width > window_height ? window_width : window_height};
    auto smaller{window_width < window_height ? window_width : window_height};
    
    UpdateCurrentFramebufferLayout(is_portrait ? smaller : bigger, is_portrait ? bigger : smaller, is_portrait);
};


bool EmulationWindow_Vulkan::CreateWindowSurface() {
    if (!host_window)
        return true;
    
    window_info.render_surface = host_window;
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface_scale = [[UIScreen mainScreen] nativeScale];
    
    return true;
};

std::unique_ptr<Frontend::GraphicsContext> EmulationWindow_Vulkan::CreateSharedContext() const {
    return std::make_unique<GraphicsContext_Apple>(driver_library);
};

void EmulationWindow_Vulkan::DestroyContext() {};
void EmulationWindow_Vulkan::DestroyWindowSurface() {};


/*
EmulationWindow_Vulkan::EmulationWindow_Vulkan(CA::MetalLayer* surface, std::shared_ptr<Common::DynamicLibrary> driver_library, bool is_secondary, CGSize size) : EmulationWindow_Apple(surface, is_secondary, size), surface{surface}, driver_library(driver_library) {
    CreateWindowSurface();
    
    if (core_context = CreateSharedContext(); !core_context)
        return;
};


void EmulationWindow_Vulkan::PollEvents() {};

void EmulationWindow_Vulkan::SizeChanged(CGSize size) {
    m_size = size;
    window_width = m_size.width;
    window_height = m_size.height;
}

void EmulationWindow_Vulkan::OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface) {
    if (is_secondary || Settings::values.layout_option.GetValue() == Settings::LayoutOption::SeparateWindows) {
        Settings::values.layout_option.SetValue(Settings::LayoutOption::SeparateWindows);
        is_portrait = false;
    } else
        is_portrait = UIInterfaceOrientationIsPortrait(orientation);
    
    OnSurfaceChanged(surface);
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
*/
