// Copyright 2014 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

#include "common/scm_rev.h"

#define GIT_REV      "76eb197f2e50c6a2e90d16d4d05cc900d739e9ef"
#define GIT_BRANCH   "master"
#define GIT_DESC     "76eb197f2"
#define BUILD_NAME   ""
#define BUILD_DATE   "2026-07-11T22:16:12Z"
#define BUILD_VERSION "0"
#define BUILD_FULLNAME "76eb197"
#define SHADER_CACHE_VERSION "720eadb59b33db946a74f3ad8bc11bec"

namespace Common {

const char g_scm_rev[]      = GIT_REV;
const char g_scm_branch[]   = GIT_BRANCH;
const char g_scm_desc[]     = GIT_DESC;
const char g_build_name[]   = BUILD_NAME;
const char g_build_date[]   = BUILD_DATE;
const char g_build_fullname[] = BUILD_FULLNAME;
const char g_build_version[]  = BUILD_VERSION;
const char g_shader_cache_version[] = SHADER_CACHE_VERSION;

} // namespace

