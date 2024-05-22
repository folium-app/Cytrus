//
//  EmulationWindow_Apple.h
//  Limon
//
//  Created by Jarrod Norwell on 1/20/24.
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
protected:
    void OnFramebufferSizeChanged();
    
    virtual bool CreateWindowSurface();
    virtual void DestroyContext();
    virtual void DestroyWindowSurface();
protected:
    CA::MetalLayer* render_window, *host_window;

    bool is_portrait;
    
    CGSize size;
    int window_width;
    int window_height;
    
    std::unique_ptr<Frontend::GraphicsContext> core_context;
};
