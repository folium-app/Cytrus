//
//  CommonTypes.h
//  Folium-iOS
//
//  Created by Jarrod Norwell on 18/4/2025.
//  Copyright © 2025 Jarrod Norwell. All rights reserved.
//

#ifndef CommonTypes_h
#define CommonTypes_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, KeyboardButtonConfig) {
    KeyboardButtonConfigSingle,
    KeyboardButtonConfigDual,
    KeyboardButtonConfigTriple,
    KeyboardButtonConfigNone
} NS_SWIFT_NAME(KeyboardButtonConfig);

NS_ASSUME_NONNULL_BEGIN

@interface KeyboardConfig : NSObject
@property (nonatomic, strong) NSString * _Nullable hintText;
@property (nonatomic, assign) KeyboardButtonConfig buttonConfig;

-(KeyboardConfig *) initWithHintText:(NSString * _Nullable)hintText buttonConfig:(KeyboardButtonConfig)buttonConfig;
@end

NS_ASSUME_NONNULL_END

#endif /* CommonTypes_h */
