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
#include "core/hle/service/am/am.h"
#include "core/hle/service/fs/archive.h"
#include "core/loader/loader.h"
#include "core/loader/smdh.h"
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

@interface CytrusGameInformation : NSObject
@property (nonatomic, strong) NSString *company, *regions, *title;
@property (nonatomic, strong) NSData *icon;

-(CytrusGameInformation *) initWithURL:(NSURL *)url;
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

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(MTKView *)metalView;
@end

NS_ASSUME_NONNULL_END
