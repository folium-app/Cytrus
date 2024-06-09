//
//  CytrusObjC.h
//  Cytrus
//
//  Created by Jarrod Norwell on 1/8/24.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "GameInformation/GameInformation.h"

#ifdef __cplusplus
#include <atomic>
#include <condition_variable>
#include <mutex>
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

//

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

//

typedef NS_ENUM(NSUInteger, InstallStatus) {
    InstallStatusSuccess,
    InstallStatusErrorFailedToOpenFile,
    InstallStatusErrorFileNotFound,
    InstallStatusErrorAborted,
    InstallStatusErrorInvalid,
    InstallStatusErrorEncrypted,
};


@interface CytrusObjC : NSObject {
#ifdef __cplusplus
    CGSize _size;
    MTKView *_mtkView;
    
    std::atomic_bool stop_run;
    std::atomic_bool pause_emulation;
    
    std::mutex paused_mutex;
    std::mutex running_mutex;
    std::condition_variable running_cv;
#endif
}

@property (nonatomic, strong) GameInformation *gameInformation;

+(CytrusObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(void) getVulkanLibrary;
-(void) setMTKView:(MTKView *)mtkView size:(CGSize)size;
-(void) run:(NSURL *)url;

-(void) updateSettings;

-(void) orientationChanged:(UIInterfaceOrientation)orientation mtkView:(MTKView *)mtkView;

-(void) touchBeganAtPoint:(CGPoint)point;
-(void) touchEnded;
-(void) touchMovedAtPoint:(CGPoint)point;

-(void) thumbstickMoved:(VirtualControllerAnalogType)analog x:(CGFloat)x y:(CGFloat)y;

-(void) virtualControllerButtonDown:(VirtualControllerButtonType)button;
-(void) virtualControllerButtonUp:(VirtualControllerButtonType)button;

-(BOOL) isPaused;
-(void) pausePlay:(BOOL)pausePlay;
-(void) stop;

-(InstallStatus) importGame:(NSURL *)url;

-(NSMutableArray<NSURL *> *) installedGamePaths;
-(NSMutableArray<NSURL *> *) systemGamePaths;
@end

NS_ASSUME_NONNULL_END
