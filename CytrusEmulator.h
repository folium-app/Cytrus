//
//  CytrusEmulator.h
//  Cytrus
//
//  Created by Jarrod Norwell on 2/7/2025.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <MetalKit/MetalKit.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#import "CheatsManager.h"
#import "GameInformationManager.h"
#import "MultiplayerManager.h"

#ifdef __cplusplus
#include <atomic>
#include <cstring>
#include <dlfcn.h>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "common/file_util.h"
#include "common/string_util.h"
#include "common/dynamic_library/dynamic_library.h"
#include "common/scope_exit.h"
#include "common/settings.h"
#include "common/string_util.h"
#include "core/core.h"
#include "core/hle/service/am/am.h"
#include "core/hw/unique_data.h"
#include "core/loader/loader.h"
#include "core/frontend/applets/default_applets.h"
#include "core/system_titles.h"
#include "input_common/main.h"
#include "network/network.h"

#include "core/hle/service/cfg/cfg.h"
#include "core/hle/service/fs/archive.h"
#include "core/hle/service/ptm/ptm.h"
#include "core/savestate.h"
#include "core/hle/service/nfc/nfc.h"
#include "network/network_settings.h"
#include "video_core/gpu.h"
#include "video_core/renderer_base.h"
#endif

@class CytrusGameInformation;
@class CytrusSaveState;

NS_ASSUME_NONNULL_BEGIN

@interface CytrusEmulator : NSObject {
#ifdef __cplusplus
    std::atomic_bool stop_run;
    std::atomic_bool pause_emulation;
    
    std::mutex paused_mutex;
    std::mutex running_mutex;
    std::condition_variable running_cv;
#endif
}

@property (nonatomic, strong) void (^disk_cache_callback) (uint8_t, size_t, size_t);

+(CytrusEmulator *) sharedInstance NS_SWIFT_NAME(shared());

-(void) allocate;
-(void) deallocate;

-(void) top:(CAMetalLayer*)layer size:(CGSize)size;
-(void) bottom:(CAMetalLayer*)layer size:(CGSize)size;
-(void) deinitialize;

-(void) insert:(NSURL *)url withCallback:(void (^)())callback NS_SWIFT_NAME(insert(from:with:));
-(BOOL) installCIA:(NSURL *)url withCallback:(void (^)())callback;

-(NSURL *) bootHome:(NSInteger)region;

-(void) touchBeganAtPoint:(CGPoint)point;
-(void) touchEnded;
-(void) touchMovedAtPoint:(CGPoint)point;

-(BOOL) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed;

-(void) thumbstickMoved:(uint32_t)analog x:(CGFloat)x y:(CGFloat)y;

-(BOOL) isPaused;
-(void) pause:(BOOL)pause;
-(void) stop;

-(BOOL) running;
-(BOOL) stopped;

-(void) orientationChanged:(UIInterfaceOrientation)orientation metalView:(UIView *)metalView secondary:(BOOL)secondary;

-(NSMutableArray<NSURL *> *) installedGamePaths;
-(NSMutableArray<NSURL *> *) systemGamePaths;

-(void) updateSettings;

-(uint16_t) stepsPerHour;
-(void) setStepsPerHour:(uint16_t)stepsPerHour;

-(BOOL) loadState;
-(BOOL) saveState;

-(BOOL) stateExists:(uint64_t)identifier forSlot:(NSInteger)slot;
-(void) load:(NSInteger)slot;
-(void) save:(NSInteger)slot;

-(BOOL) insertAmiibo:(NSURL *)url;
-(void) removeAbiibo;

-(void) loadConfig;
-(int) getSystemLanguage NS_SWIFT_NAME(systemLanguage());
-(void) setSystemLanguage:(int)systemLanguage NS_SWIFT_NAME(set(systemLanguage:));
-(NSString *) getUsername NS_SWIFT_NAME(username());
-(void) setUsername:(NSString *)username NS_SWIFT_NAME(set(username:));

-(NSArray *) saveStates:(uint64_t)identifier;
-(NSString *) saveStatePath:(uint64_t)identifier slot:(NSInteger)slot NS_SWIFT_NAME(saveStatePath(_:_:));
@end

NS_ASSUME_NONNULL_END
