//
//  EmulationWindow_Vulkan.h
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#import <UIKit/UIKit.h>

#import <Metal.hpp>

#include "core/frontend/emu_window.h"

class EmulationWindow_Vulkan : public Frontend::EmuWindow {
public:
    EmulationWindow_Vulkan(CA::MetalLayer* surface, bool is_secondary, std::shared_ptr<Common::DynamicLibrary> driver_library, CGSize size);
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
    
    void SizeChanged(CGSize size);
    void OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface);
protected:
    void OnFramebufferSizeChanged();
    
    bool CreateWindowSurface();
    void DestroyContext();
    void DestroyWindowSurface();
protected:
    CA::MetalLayer* render_window;
    CA::MetalLayer* host_window;

    bool is_portrait;
    
    CGSize m_size;
    
    std::shared_ptr<Common::DynamicLibrary> driver_library;
    
    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
    std::unique_ptr<Frontend::GraphicsContext> core_context;
};






// #include "EmulationWindow_Apple.h"



/*
 class EmulationWindow_Vulkan : public EmulationWindow_Apple {
 public:
 EmulationWindow_Vulkan(CA::MetalLayer* surface, std::shared_ptr<Common::DynamicLibrary> driver_library, bool is_secondary, CGSize size);
 ~EmulationWindow_Vulkan() = default;
 
 void PollEvents() override;
 
 void SizeChanged(CGSize size);
 void OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface);
 
 std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
 
 CA::MetalLayer* surface;
 private:
 bool CreateWindowSurface() override;
 
 std::shared_ptr<Common::DynamicLibrary> driver_library;
 };
 */
