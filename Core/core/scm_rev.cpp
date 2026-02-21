// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include "common/scm_rev.h"

#include <string>

#define GIT_BRANCH   "@GIT_BRANCH@"
#define GIT_DESC     "@GIT_DESC@"
#define BUILD_NAME   "@REPO_NAME@"
#define BUILD_VERSION "@BUILD_VERSION@"
#define SHADER_CACHE_VERSION "@SHADER_CACHE_VERSION@"

#import "BuildStrings.h"

namespace Common {

const char* g_scm_rev      = buildRevision();
const char g_scm_branch[]   = GIT_BRANCH;
const char g_scm_desc[]     = GIT_DESC;
const char g_build_name[]   = BUILD_NAME;
const char* g_build_date   = gitDate();
const char* g_build_fullname = buildFullName();
const char g_build_version[]  = BUILD_VERSION;
const char g_shader_cache_version[] = SHADER_CACHE_VERSION;

} // namespace
