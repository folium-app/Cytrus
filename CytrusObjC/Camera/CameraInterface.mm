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

#include "core/hle/service/cam/cam.h"

void convertYUV420ToRGB565(uint8_t *yPlane, uint8_t *uvPlane, std::vector<uint16_t>& rgb565Buffer, int width, int height) {
    rgb565Buffer.clear();
    rgb565Buffer.reserve(width * height);
    
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i++) {
            uint8_t y = yPlane[j * width + i];
            uint8_t u = uvPlane[(j / 2) * width + (i & ~1)];
            uint8_t v = uvPlane[(j / 2) * width + (i & ~1) + 1];
            
            int c = y - 16;
            int d = u - 128;
            int e = v - 128;
            
            int r = (298 * c + 409 * e + 128) >> 8;
            int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
            int b = (298 * c + 516 * d + 128) >> 8;
            
            r = std::max(0, std::min(255, r));
            g = std::max(0, std::min(255, g));
            b = std::max(0, std::min(255, b));
            
            uint16_t rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
            
            rgb565Buffer.push_back(rgb565);
        }
    }
}

void convertYUV420ToYUV422(uint8_t *yPlane, uint8_t *uvPlane, std::vector<uint16_t>& yuv422Buffer, int width, int height) {
    yuv422Buffer.clear();
    yuv422Buffer.reserve(width * height);
    
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i += 2) {
            uint8_t y0 = yPlane[j * width + i];
            uint8_t y1 = yPlane[j * width + i + 1];
            
            uint8_t u = uvPlane[(j / 2) * width + (i & ~1)];
            uint8_t v = uvPlane[(j / 2) * width + (i & ~1) + 1];
            
            uint16_t yuv1 = (y0 << 8) | u;
            uint16_t yuv2 = (y1 << 8) | v;
            
            yuv422Buffer.push_back(yuv1);
            yuv422Buffer.push_back(yuv2);
        }
    }
}

@interface ObjCCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession *captureSession;
    AVCaptureVideoDataOutput *videoOutput;
    
    BOOL isRGB565;
    
    std::vector<uint16_t> framebuffer;
    
    CGFloat _width, _height;
}

+(ObjCCamera *) sharedInstance;

-(void) stop;
-(void) start;

-(void) resolution:(Service::CAM::Resolution)arg1;
-(void) format:(Service::CAM::OutputFormat)arg1;

-(std::vector<uint16_t>) frame;
-(CGFloat) width;
-(CGFloat) height;
@end

@implementation ObjCCamera
-(ObjCCamera *) init {
    if (self = [super init]) {
        captureSession = [[AVCaptureSession alloc] init];
        captureSession.sessionPreset = AVCaptureSessionPresetHigh;

        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        NSError *error = NULL;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

        if (!error && [captureSession canAddInput:input])
            [captureSession addInput:input];
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
    if ([captureSession isRunning])
        [captureSession stopRunning];
}

-(void) start {
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *outputSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (NSString *)kCVPixelBufferWidthKey : @(_width),
        (NSString *)kCVPixelBufferHeightKey : @(_height)
    };
    [videoOutput setVideoSettings:outputSettings];
    [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    if ([captureSession canAddOutput:videoOutput])
        [captureSession addOutput:videoOutput];
    
    if (![captureSession isRunning])
        [captureSession startRunning];
}

-(void) resolution:(Service::CAM::Resolution)arg1 {
    _width = arg1.width;
    _height = arg1.height;
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
    CVPixelBufferRef pixelBuffer = [self scaledPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) toSize:{_width, _height}];
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t *yPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *uvPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    if (isRGB565)
        convertYUV420ToRGB565(yPlane, uvPlane, framebuffer, _width, _height);
    else
        convertYUV420ToYUV422(yPlane, uvPlane, framebuffer, _width, _height);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (CVPixelBufferRef)scaledPixelBuffer:(CVPixelBufferRef)pixelBuffer toSize:(CGSize)size {
    // Create a CIImage from the CVPixelBuffer
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    // Create a CIContext for rendering
    CIContext *context = [CIContext contextWithOptions:NULL];
    
    // Define the target size for the output pixel buffer
    CGSize targetSize = size;
    
    // Create a new pixel buffer to hold the scaled image
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    CVPixelBufferRef scaledPixelBuffer;
    CVPixelBufferCreate(kCFAllocatorDefault, targetSize.width, targetSize.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, (__bridge CFDictionaryRef)pixelBufferAttributes, &scaledPixelBuffer);
    
    // Lock the new pixel buffer
    CVPixelBufferLockBaseAddress(scaledPixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    // Render the CIImage to the new pixel buffer
    [context render:ciImage toCVPixelBuffer:scaledPixelBuffer];
    
    // Unlock the pixel buffer
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
