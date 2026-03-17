// Copyright 2015 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Includes the MicroProfile implementation in this file for compilation

#if __APPLE__
#import <TargetConditionals.h>
#endif

#if TARGET_OS_IOS
#define MICROPROFILE_IMPL 0
#else
#define MICROPROFILE_IMPL 1
#endif
#include "common/microprofile.h"
