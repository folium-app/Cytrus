//
//  GraphicsContext_Apple.cpp
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#include "GraphicsContext_Apple.h"

GraphicsContext_Apple::GraphicsContext_Apple(std::shared_ptr<Common::DynamicLibrary> driver_library) : driver_library(driver_library) {};

std::shared_ptr<Common::DynamicLibrary> GraphicsContext_Apple::GetDriverLibrary() {
    return driver_library;
};
