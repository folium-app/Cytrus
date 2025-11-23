//
//  GraphicsContext_Apple.h
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#pragma once

#include "common/dynamic_library/dynamic_library.h"
#include "core/frontend/emu_window.h"

class GraphicsContext_Apple : public Frontend::GraphicsContext {
public:
    explicit GraphicsContext_Apple(std::shared_ptr<Common::DynamicLibrary> driver_library);
    ~GraphicsContext_Apple() = default;

    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override;
private:
    std::shared_ptr<Common::DynamicLibrary> driver_library;
};
