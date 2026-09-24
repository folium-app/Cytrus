//
//  emu_window_vk.cpp
//  Cytrus
//
//  Created by Jarrod Norwell on 13/7/2026.
//

#include "emu_window_vk.h"

GraphicsContext_Apple::GraphicsContext_Apple(std::shared_ptr<Common::DynamicLibrary> driver_library) : driver_library(driver_library) {};

std::shared_ptr<Common::DynamicLibrary> GraphicsContext_Apple::GetDriverLibrary() {
    return driver_library;
};

EmulationWindow_Vulkan::EmulationWindow_Vulkan(CA::MetalLayer* surface, bool is_secondary, std::shared_ptr<Common::DynamicLibrary> driver_library, double size_h, double size_w) : Frontend::EmuWindow(is_secondary), host_window(surface), m_size_h(size_h), m_size_w(size_w), driver_library(driver_library) {
    if (Settings::values.layout_option.GetValue() == Settings::LayoutOption::SeparateWindows)
        is_portrait = false;
    else
        is_portrait = true;
    
    if (!surface)
        return;
    
    window_height = m_size_h;
    window_width = m_size_w;
    
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
    window_info.render_surface_scale = 3.0f;

    StopPresenting();
    OnFramebufferSizeChanged();
};

void EmulationWindow_Vulkan::SizeChanged(double h, double w) {
    m_size_h = h;
    m_size_w = w;
    
    window_height = m_size_h;
    window_width = m_size_w;
}

void EmulationWindow_Vulkan::OrientationChanged(int orientation, CA::MetalLayer* surface) {
    if (Settings::values.layout_option.GetValue() != Settings::LayoutOption::SeparateWindows)
        is_portrait = orientation == 1;
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
    auto bigger{window_width > window_height ? window_width : window_height};
    auto smaller{window_width < window_height ? window_width : window_height};
    
    UpdateCurrentFramebufferLayout(is_portrait ? smaller : bigger, is_portrait ? bigger : smaller, is_portrait);
};


bool EmulationWindow_Vulkan::CreateWindowSurface() {
    if (!host_window)
        return true;
    
    window_info.render_surface = host_window;
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface_scale = 3.0f;
    
    return true;
};

std::unique_ptr<Frontend::GraphicsContext> EmulationWindow_Vulkan::CreateSharedContext() const {
    return std::make_unique<GraphicsContext_Apple>(driver_library);
};

void EmulationWindow_Vulkan::DestroyContext() {};
void EmulationWindow_Vulkan::DestroyWindowSurface() {};
