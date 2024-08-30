//
//  CameraInterface.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 27/8/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "CameraInterface.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "core/hle/service/cam/cam.h"

#include <libyuv/libyuv.h> // unused for now

@interface ObjCCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureDevice *device;
    AVCaptureSession *session;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    
    BOOL isRGB565;
    
    std::vector<uint16_t> framebuffer;
    
    int64_t minFramesPerSecond, maxFramesPerSecond;
    CGFloat _width, _height;
}

+(ObjCCamera *) sharedInstance;

-(void) stop;
-(void) start;

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1;
-(void) resolution:(Service::CAM::Resolution)arg1;
-(void) format:(Service::CAM::OutputFormat)arg1;

-(std::vector<uint16_t>) frame;
-(CGFloat) width;
-(CGFloat) height;
@end

@implementation ObjCCamera
-(ObjCCamera *) init {
    if (self = [super init]) {
        session = [[AVCaptureSession alloc] init];
        [session setSessionPreset:AVCaptureSessionPresetHigh];
        
        NSArray<AVCaptureDevice *> *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeBuiltInWideAngleCamera
        ] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified].devices;
        
        [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
            if ([obj position] == AVCaptureDevicePositionBack) {
                device = obj;
                *stop = TRUE;
            }
        }];
    } return self;
}

+(ObjCCamera *) sharedInstance {
    static ObjCCamera *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) stop {
    if ([session isRunning])
        [session stopRunning];
    
    [session removeInput:input];
    [session removeOutput:output];
}

-(void) start {
    [device lockForConfiguration:NULL];
    // configure
    [device setActiveVideoMinFrameDuration:CMTimeMake(1, minFramesPerSecond)];
    [device setActiveVideoMaxFrameDuration:CMTimeMake(1, maxFramesPerSecond)];
    [device unlockForConfiguration];
    
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
    
    if ([session canAddInput:input])
        [session addInput:input];
    
    output = [[AVCaptureVideoDataOutput alloc] init];
    
    NSDictionary *settings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
    
    [output setVideoSettings:settings];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    if ([session canAddOutput:output])
        [session addOutput:output];
    
    if (![session isRunning])
        [session startRunning];
}

-(void) framesPerSecond:(Service::CAM::FrameRate)arg1 {
    switch (arg1) {
        case Service::CAM::FrameRate::Rate_15:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_15_To_2:
            minFramesPerSecond = 2;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_10:
            minFramesPerSecond = maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_8_5:
            minFramesPerSecond = maxFramesPerSecond = 8.5;
            break;
        case Service::CAM::FrameRate::Rate_5:
            minFramesPerSecond = maxFramesPerSecond = 5;
            break;
        case Service::CAM::FrameRate::Rate_20:
            minFramesPerSecond = maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_20_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30:
            minFramesPerSecond = maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_30_To_5:
            minFramesPerSecond = 5;
            maxFramesPerSecond = 30;
            break;
        case Service::CAM::FrameRate::Rate_15_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 15;
            break;
        case Service::CAM::FrameRate::Rate_20_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 20;
            break;
        case Service::CAM::FrameRate::Rate_30_To_10:
            minFramesPerSecond = 10;
            maxFramesPerSecond = 30;
            break;
    }
}

-(void) resolution:(Service::CAM::Resolution)arg1 {
    _width = arg1.width;
    _height = arg1.height;
    framebuffer.resize(_height * _width);
}

-(void) format:(Service::CAM::OutputFormat)arg1 {
    isRGB565 = arg1 == Service::CAM::OutputFormat::RGB565;
}

-(std::vector<uint16_t>) frame {
    return framebuffer;
}

-(CGFloat) width {
    return _width;
}

-(CGFloat) height {
    return _height;
}

-(void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [connection setVideoOrientation:(AVCaptureVideoOrientation)[[UIDevice currentDevice] orientation]];
    
    CVPixelBufferRef ref = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferRef pixelBuffer = [self scaledPixelBuffer:ref toSize:{_width, _height}];
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t *bgraData = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bgraStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (isRGB565) {
        std::vector<uint16_t> rgb565Buffer(width * height);
        
        for (size_t y = 0; y < height; ++y) {
            for (size_t x = 0; x < width; ++x) {
                size_t bgraOffset = y * bgraStride + x * 4;
                
                uint8_t b = bgraData[bgraOffset];
                uint8_t g = bgraData[bgraOffset + 1];
                uint8_t r = bgraData[bgraOffset + 2];
                
                rgb565Buffer[y * width + x] = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
            }
        }
        
        memcpy(framebuffer.data(), rgb565Buffer.data(), width * height * sizeof(uint16_t));
    }
}

-(CVPixelBufferRef) scaledPixelBuffer:(CVPixelBufferRef)pixelBuffer toSize:(CGSize)size {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:NULL];
    
    CGSize inputSize = ciImage.extent.size;
    
    CGFloat widthScale = size.width / inputSize.width;
    CGFloat heightScale = size.height / inputSize.height;
    CGFloat scaleFactor = MIN(widthScale, heightScale);
    
    CGSize scaledSize = CGSizeMake(inputSize.width * scaleFactor, inputSize.height * scaleFactor);
    
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    CVPixelBufferRef scaledPixelBuffer;
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &scaledPixelBuffer);
    
    CVPixelBufferLockBaseAddress(scaledPixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
    CIImage *scaledImage = [ciImage imageByApplyingTransform:scaleTransform];
    
    CGFloat offsetX = (size.width - scaledSize.width) / 2.0;
    CGFloat offsetY = (size.height - scaledSize.height) / 2.0;
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(offsetX, offsetY);
    CIImage *centeredImage = [scaledImage imageByApplyingTransform:translateTransform];
    
    [context render:centeredImage toCVPixelBuffer:scaledPixelBuffer];
    
    CVPixelBufferUnlockBaseAddress(scaledPixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return scaledPixelBuffer;
}
@end

namespace Camera {
iOSCameraInterface::~iOSCameraInterface() {}

void iOSCameraInterface::StartCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCCamera sharedInstance] start];
};

void iOSCameraInterface::StopCapture() {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCCamera sharedInstance] stop];
};

void iOSCameraInterface::SetResolution(const Service::CAM::Resolution& resolution) {
    NSLog(@"%s, %hu, %hu", __FUNCTION__, resolution.width, resolution.height);
    [[ObjCCamera sharedInstance] resolution:resolution];
};

void iOSCameraInterface::SetFlip(Service::CAM::Flip flip) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSCameraInterface::SetEffect(Service::CAM::Effect effect) {
    NSLog(@"%s", __FUNCTION__);
};

void iOSCameraInterface::SetFormat(Service::CAM::OutputFormat format) {
    NSLog(@"%s, %hhu", __FUNCTION__, format);
    [[ObjCCamera sharedInstance] format:format];
};

void iOSCameraInterface::SetFrameRate(Service::CAM::FrameRate frame_rate) {
    NSLog(@"%s", __FUNCTION__);
    [[ObjCCamera sharedInstance] framesPerSecond:frame_rate];
};

std::vector<u16> iOSCameraInterface::ReceiveFrame() {
    NSLog(@"%s", __FUNCTION__);
    return [[ObjCCamera sharedInstance] frame];
};

bool iOSCameraInterface::IsPreviewAvailable() {
    NSLog(@"%s", __FUNCTION__);
    return true;
};
}

// MARK: Missing from Citra
/*
 SetNoiseFilter
 SetAutoExposure
 SetAutoWhiteBalance
 */
