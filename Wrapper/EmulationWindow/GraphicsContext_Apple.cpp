//
//  GraphicsContext_Apple.cpp
//  Limon
//
//  Created by Jarrod Norwell on 1/20/24.
//

#include "GraphicsContext_Apple.h"

GraphicsContext_Apple::GraphicsContext_Apple(std::shared_ptr<Common::DynamicLibrary> driver_library) : driver_library(driver_library) {};

std::shared_ptr<Common::DynamicLibrary> GraphicsContext_Apple::GetDriverLibrary() {
    return driver_library;
};
