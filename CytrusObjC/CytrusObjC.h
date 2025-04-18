//
//  CytrusObjC.h
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <MetalKit/MetalKit.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#import "CheatsManager.h"
#import "GameInformation.h"
#import "MultiplayerManager.h"

#ifdef __cplusplus
#include <atomic>
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
#include "common/string_util.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"

#include "core/hle/service/cfg/cfg.h"
#include "core/hle/service/fs/archive.h"
#include "core/hle/service/ptm/ptm.h"
#include "core/savestate.h"
#include "network/network_settings.h"
#include "video_core/gpu.h"
#include "video_core/renderer_base.h"
#endif

NS_ASSUME_NONNULL_BEGIN

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

@property (nonatomic, strong) void (^disk_cache_callback) (uint8_t, size_t, size_t);

+(CytrusObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(GameInformation *) information:(NSURL *)url NS_SWIFT_NAME(information(from:));

-(void) allocate;
-(void) deallocate;

-(void) initialize:(CAMetalLayer*)layer size:(CGSize)size secondary:(BOOL)secondary;
-(void) deinitialize;

-(void) insert:(NSURL *)url NS_SWIFT_NAME(insert(from:));

-(uint32_t) import:(NSURL *)url NS_SWIFT_NAME(import(from:));

-(void) touchBeganAtPoint:(CGPoint)point;
-(void) touchEnded;
-(void) touchMovedAtPoint:(CGPoint)point;

-(BOOL) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed;

-(void) thumbstickMoved:(uint32_t)analog x:(CGFloat)x y:(CGFloat)y;

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

-(BOOL) loadState;
-(BOOL) saveState;

-(void) loadConfig;
-(int) getSystemLanguage NS_SWIFT_NAME(systemLanguage());
-(void) setSystemLanguage:(int)systemLanguage NS_SWIFT_NAME(set(systemLanguage:));
-(NSString *) getUsername NS_SWIFT_NAME(username());
-(void) setUsername:(NSString *)username NS_SWIFT_NAME(set(username:));

-(NSArray<SaveStateInfo *> *) saveStates:(uint64_t)identifier;
-(NSString *) saveStatePath:(uint64_t)identifier;
@end

NS_ASSUME_NONNULL_END
