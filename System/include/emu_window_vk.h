//
//  emu_window_vk.h
//  Cytrus
//
//  Created by Jarrod Norwell on 13/7/2026.
//

#pragma once

#include "common/dynamic_library/dynamic_library.h"
#include "core/frontend/emu_window.h"

#import <Metal.hpp>

class GraphicsContext_Apple : public Frontend::GraphicsContext {
public:
    explicit GraphicsContext_Apple(std::shared_ptr<Common::DynamicLibrary> driver_library);
    ~GraphicsContext_Apple() = default;

    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override;
private:
    std::shared_ptr<Common::DynamicLibrary> driver_library;
};

class EmulationWindow_Vulkan : public Frontend::EmuWindow {
public:
    EmulationWindow_Vulkan(CA::MetalLayer*, bool, std::shared_ptr<Common::DynamicLibrary>, double, double);
    ~EmulationWindow_Vulkan();
    
    void PollEvents() override;
    
    void OnSurfaceChanged(CA::MetalLayer* surface);
    
    void OnTouchEvent(int x, int y);
    void OnTouchMoved(int x, int y);
    void OnTouchReleased();

    void DoneCurrent() override;
    void MakeCurrent() override;

    void StopPresenting();
    void TryPresenting();
    
    int window_width;
    int window_height;
    
    void SizeChanged(double, double);
    void OrientationChanged(int orientation, CA::MetalLayer* surface);
protected:
    void OnFramebufferSizeChanged();
    
    bool CreateWindowSurface();
    void DestroyContext();
    void DestroyWindowSurface();
protected:
    CA::MetalLayer* render_window;
    CA::MetalLayer* host_window;

    bool is_portrait;
    
    double m_size_h, m_size_w;
    
    std::shared_ptr<Common::DynamicLibrary> driver_library;
    
    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
    std::unique_ptr<Frontend::GraphicsContext> core_context;
};
