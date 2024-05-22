//
//  EmulationWindow_Vulkan.h
//  Limon
//
//  Created by Jarrod Norwell on 1/20/24.
//

#import <UIKit/UIKit.h>

#include "EmulationWindow_Apple.h"

class EmulationWindow_Vulkan : public EmulationWindow_Apple {
public:
    EmulationWindow_Vulkan(CA::MetalLayer* surface, std::shared_ptr<Common::DynamicLibrary> driver_library, bool is_secondary, CGSize size);
    ~EmulationWindow_Vulkan() = default;
    
    void PollEvents() override;
    
    void OrientationChanged(UIInterfaceOrientation orientation, CA::MetalLayer* surface);
    
    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
    
    CA::MetalLayer* surface;
private:
    bool CreateWindowSurface() override;
    
    std::shared_ptr<Common::DynamicLibrary> driver_library;
};
