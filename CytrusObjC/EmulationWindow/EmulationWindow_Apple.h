//
//  EmulationWindow_Apple.h
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#import <Metal/Metal.hpp>

#include "core/frontend/emu_window.h"

class EmulationWindow_Apple : public Frontend::EmuWindow {
public:
    EmulationWindow_Apple(CA::MetalLayer* surface, bool is_secondary, CGSize size);
    ~EmulationWindow_Apple();
    
    void OnSurfaceChanged(CA::MetalLayer* surface);
    
    void OnTouchEvent(int x, int y);
    void OnTouchMoved(int x, int y);
    void OnTouchReleased();

    void DoneCurrent() override;
    void MakeCurrent() override;

    virtual void StopPresenting();
    virtual void TryPresenting();
    
    int window_width;
    int window_height;
protected:
    void OnFramebufferSizeChanged();
    
    virtual bool CreateWindowSurface();
    virtual void DestroyContext();
    virtual void DestroyWindowSurface();
protected:
    CA::MetalLayer* render_window;
    CA::MetalLayer* host_window;

    bool is_portrait;
    
    CGSize m_size;
    
    std::unique_ptr<Frontend::GraphicsContext> core_context;
};
