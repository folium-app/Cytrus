//
//  Keyboard.h
//  Cytrus
//
//  Created by Jarrod Norwell on 18/4/2025.
//  Copyright © 2025 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Common.h"

#ifdef __cplusplus
#include "core/frontend/applets/swkbd.h"

#include <condition_variable>
#include <future>

namespace SoftwareKeyboard {
class Keyboard final : public Frontend::SoftwareKeyboard {
public:
    ~Keyboard();
    
    void Execute(const Frontend::KeyboardConfig& config) override;
    void ShowError(const std::string& error) override;
    
    void KeyboardText(std::condition_variable& cv);
    std::pair<std::string, uint8_t> GetKeyboardText(const Frontend::KeyboardConfig& config);
    
private:
    __block NSString *_Nullable keyboardText = @"";
    __block uint8_t buttonPressed = 0;
    
    __block BOOL isReady = FALSE;
};
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface KeyboardConfig : NSObject
@property (nonatomic, strong) NSString * _Nullable hintText;
@property (nonatomic, assign) ButtonConfig buttonConfig;

-(KeyboardConfig *) initWithHintText:(NSString * _Nullable)hintText buttonConfig:(ButtonConfig)buttonConfig;
@end

NS_ASSUME_NONNULL_END
