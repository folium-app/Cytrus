//
//  BuildStrings.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 15/3/2025.
//  Copyright © 2025 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BuildStrings.h"

const char* gitDate(void) {
    NSDate *date = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"GIT_DATE"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return [[formatter stringFromDate:date] UTF8String];
}

const char* buildRevision(void) {
    NSString *revision = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"GIT_REV"];
    return [revision UTF8String];
}

const char* buildFullName(void) {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    return [[NSString stringWithFormat:@"%@.%@", version, build] UTF8String];
}
