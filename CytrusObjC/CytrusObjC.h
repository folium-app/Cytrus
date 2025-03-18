//
//  CytrusObjC.h
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "CheatsManager.h"
#import "MultiplayerManager.h"

#ifdef __cplusplus
#include <atomic>
#include <condition_variable>
#include <cstring>
#include <dlfcn.h>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "common/string_util.h"
#include "common/dynamic_library/dynamic_library.h"
#include "common/scope_exit.h"
#include "common/settings.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/frontend/applets/swkbd.h"
#include "core/hle/service/am/am.h"
#include "core/hle/service/fs/archive.h"
#include "core/loader/loader.h"
#include "core/loader/smdh.h"
#include "core/savestate.h"
#include "network/network_settings.h"
#include "video_core/gpu.h"
#include "video_core/renderer_base.h"

namespace InformationForGame {
std::vector<u8> GetSMDHData(const std::string& path) {
    std::unique_ptr<Loader::AppLoader> loader = Loader::GetLoader(path);
    if (!loader) {
        return {};
    }
    
    u64 program_id = 0;
    loader->ReadProgramId(program_id);
    
    std::vector<u8> smdh = [program_id, &loader]() -> std::vector<u8> {
        std::vector<u8> original_smdh;
        loader->ReadIcon(original_smdh);
        
        if (program_id < 0x00040000'00000000 || program_id > 0x00040000'FFFFFFFF)
            return original_smdh;
        
        std::string update_path = Service::AM::GetTitleContentPath(Service::FS::MediaType::SDMC, program_id + 0x0000000E'00000000);
        
        if (!FileUtil::Exists(update_path))
            return original_smdh;
        
        std::unique_ptr<Loader::AppLoader> update_loader = Loader::GetLoader(update_path);
        
        if (!update_loader)
            return original_smdh;
        
        std::vector<u8> update_smdh;
        update_loader->ReadIcon(update_smdh);
        return update_smdh;
    }();
    
    return smdh;
}

std::vector<uint16_t> Icon(std::vector<uint8_t> smdh_data) {
    if (!Loader::IsValidSMDH(smdh_data)) {
        // SMDH is not valid, return null
        return std::vector<uint16_t>(0, 0);
    }
    
    Loader::SMDH smdh;
    memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
    
    // Always get a 48x48(large) icon
    std::vector<uint16_t> icon_data = smdh.GetIcon(true);
    return icon_data;
}


std::u16string Publisher(std::vector<uint8_t> smdh_data) {
    Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
    
    if (!Loader::IsValidSMDH(smdh_data)) {
        // SMDH is not valid, return null
        return {};
    }
    
    Loader::SMDH smdh;
    memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
    
    // Get the Publisher's name from SMDH in UTF-16 format
    char16_t* publisher;
    publisher =
    reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].publisher.data());
    
    return publisher;
}

std::string Regions(std::vector<uint8_t> smdh_data) {
    if (!Loader::IsValidSMDH(smdh_data)) {
        // SMDH is not valid, return "Invalid region"
        return "Invalid region";
    }
    
    Loader::SMDH smdh;
    memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
    
    using GameRegion = Loader::SMDH::GameRegion;
    static const std::map<GameRegion, const char*> regions_map = {
        {GameRegion::Japan, "Japan"},   {GameRegion::NorthAmerica, "North America"},
        {GameRegion::Europe, "Europe"}, {GameRegion::Australia, "Australia"},
        {GameRegion::China, "China"},   {GameRegion::Korea, "Korea"},
        {GameRegion::Taiwan, "Taiwan"}};
    std::vector<GameRegion> regions = smdh.GetRegions();
    
    if (regions.empty()) {
        return "Invalid region";
    }
    
    const bool region_free =
    std::all_of(regions_map.begin(), regions_map.end(), [&regions](const auto& it) {
        return std::find(regions.begin(), regions.end(), it.first) != regions.end();
    });
    
    if (region_free) {
        return "Region free";
    }
    
    const std::string separator = ", ";
    std::string result = regions_map.at(regions.front());
    for (auto region = ++regions.begin(); region != regions.end(); ++region) {
        result += separator + regions_map.at(*region);
    }
    
    return result;
}

std::u16string Title(std::vector<uint8_t> smdh_data) {
    Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
    
    if (!Loader::IsValidSMDH(smdh_data)) {
        // SMDH is not valid, return null
        return {};
    }
    
    Loader::SMDH smdh;
    memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
    
    // Get the title from SMDH in UTF-16 format
    std::u16string title{
        reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].long_title.data())};
    
    return title;
}

bool IsSystemTitle(std::string physical_name) {
    std::unique_ptr<Loader::AppLoader> loader = Loader::GetLoader(physical_name);
    if (!loader) {
        return false;
    }
    
    u64 program_id ={};
    loader->ReadProgramId(program_id);
    return ((program_id >> 32) & 0xFFFFFFFF) == 0x00040010;
}
}
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VirtualControllerAnalogType) {
    VirtualControllerAnalogTypeCirclePad = 713,
    VirtualControllerAnalogTypeCirclePadUp = 714,
    VirtualControllerAnalogTypeCirclePadDown = 715,
    VirtualControllerAnalogTypeCirclePadLeft = 716,
    VirtualControllerAnalogTypeCirclePadRight = 717,
    VirtualControllerAnalogTypeCStick = 718,
    VirtualControllerAnalogTypeCStickUp = 719,
    VirtualControllerAnalogTypeCStickDown = 720,
    VirtualControllerAnalogTypeCStickLeft = 771,
    VirtualControllerAnalogTypeCStickRight = 772
};

typedef NS_ENUM(NSUInteger, VirtualControllerButtonType) {
    VirtualControllerButtonTypeA = 700,
    VirtualControllerButtonTypeB = 701,
    VirtualControllerButtonTypeX = 702,
    VirtualControllerButtonTypeY = 703,
    VirtualControllerButtonTypeStart = 704,
    VirtualControllerButtonTypeSelect = 705,
    VirtualControllerButtonTypeHome = 706,
    VirtualControllerButtonTypeTriggerZL = 707,
    VirtualControllerButtonTypeTriggerZR = 708,
    VirtualControllerButtonTypeDirectionalPadUp = 709,
    VirtualControllerButtonTypeDirectionalPadDown = 710,
    VirtualControllerButtonTypeDirectionalPadLeft = 711,
    VirtualControllerButtonTypeDirectionalPadRight = 712,
    VirtualControllerButtonTypeTriggerL = 773,
    VirtualControllerButtonTypeTriggerR = 774,
    VirtualControllerButtonTypeDebug = 781,
    VirtualControllerButtonTypeGPIO14 = 782
};

typedef NS_ENUM(NSUInteger, ImportResultStatus) {
    ImportResultStatusSuccess,
    ImportResultStatusErrorFailedToOpenFile,
    ImportResultStatusErrorFileNotFound,
    ImportResultStatusErrorAborted,
    ImportResultStatusErrorInvalid,
    ImportResultStatusErrorEncrypted,
};

typedef NS_ENUM(NSUInteger, KeyboardButtonConfig) {
    KeyboardButtonConfigSingle,
    KeyboardButtonConfigDual,
    KeyboardButtonConfigTriple,
    KeyboardButtonConfigNone
};

@interface KeyboardConfig : NSObject
@property (nonatomic, strong) NSString * _Nullable hintText;
@property (nonatomic, assign) KeyboardButtonConfig buttonConfig;

-(KeyboardConfig *) initWithHintText:(NSString * _Nullable)hintText buttonConfig:(KeyboardButtonConfig)buttonConfig;
@end

typedef NS_ENUM(uint8_t, KernelMemoryMode) {
    KernelMemoryModeProd = 0, ///< 64MB app memory
    KernelMemoryModeDev1 = 2, ///< 96MB app memory
    KernelMemoryModeDev2 = 3, ///< 80MB app memory
    KernelMemoryModeDev3 = 4, ///< 72MB app memory
    KernelMemoryModeDev4 = 5 ///< 32MB app memory
};

typedef NS_ENUM(uint8_t, New3DSKernelMemoryMode) {
    New3DSKernelMemoryModeLegacy = 0,  ///< Use Old 3DS system mode.
    New3DSKernelMemoryModeProd = 1, ///< 124MB app memory
    New3DSKernelMemoryModeDev1 = 2, ///< 178MB app memory
    New3DSKernelMemoryModeDev2 = 3 ///< 124MB app memory
};

@interface CoreVersion : NSObject
@property (nonatomic) uint32_t major, minor, revision;

-(CoreVersion *) initWithCoreVersion:(uint32_t)coreVersion;
@end

@interface CytrusGameInformation : NSObject
@property (nonatomic) CoreVersion *coreVersion;
@property (nonatomic) uint64_t identifier;
@property (nonatomic) KernelMemoryMode kernelMemoryMode;
@property (nonatomic) New3DSKernelMemoryMode new3DSKernelMemoryMode;

@property (nonatomic, strong) NSString *regions, *publisher, *title;
@property (nonatomic, strong) NSData * _Nullable icon;

-(CytrusGameInformation *) initWithURL:(NSURL *)url;
@end

@interface SaveStateInfo : NSObject
@property (nonatomic) uint32_t slot;
@property (nonatomic) uint64_t time;
@property (nonatomic, strong) NSString *buildName;
@property (nonatomic) int status;

-(SaveStateInfo *) initWithSlot:(uint32_t)slot time:(uint64_t)time buildName:(NSString *)buildName status:(int)status;
@end


@interface CytrusObjC : NSObject {
#ifdef __cplusplus
    std::atomic_bool stop_run;
    std::atomic_bool pause_emulation;
    
    std::mutex paused_mutex;
    std::mutex running_mutex;
    std::condition_variable running_cv;
#endif
}

+(CytrusObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(CytrusGameInformation *) informationForGameAt:(NSURL *)url NS_SWIFT_NAME(informationForGame(at:));

-(void) allocateVulkanLibrary;
-(void) deallocateVulkanLibrary;

-(void) allocateMetalLayer:(CAMetalLayer*)layer withSize:(CGSize)size isSecondary:(BOOL)secondary;
-(void) deallocateMetalLayers;

-(void) insertCartridgeAndBoot:(NSURL *)url;

-(ImportResultStatus) importGameAt:(NSURL *)url NS_SWIFT_NAME(importGame(at:));

-(void) touchBeganAtPoint:(CGPoint)point;
-(void) touchEnded;
-(void) touchMovedAtPoint:(CGPoint)point;

-(void) virtualControllerButtonDown:(VirtualControllerButtonType)button;
-(void) virtualControllerButtonUp:(VirtualControllerButtonType)button;

-(void) thumbstickMoved:(VirtualControllerAnalogType)analog x:(CGFloat)x y:(CGFloat)y;

-(BOOL) isPaused;
-(void) pausePlay:(BOOL)pausePlay;
-(void) stop;

-(BOOL) running;
-(BOOL) stopped;

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(UIView *)metalView;

-(NSMutableArray<NSURL *> *) installedGamePaths;
-(NSMutableArray<NSURL *> *) systemGamePaths;

-(void) updateSettings;

-(uint16_t) stepsPerHour;
-(void) setStepsPerHour:(uint16_t)stepsPerHour;

-(void) loadState;
-(void) saveState;

-(NSArray<SaveStateInfo *> *) saveStates:(uint64_t)identifier;
-(NSString *) saveStatePath:(uint64_t)identifier;
@end

NS_ASSUME_NONNULL_END
