//
//  GameInformationManager.h
//  Cytrus
//
//  Created by Jarrod Norwell on 15/7/2025.
//

#import <Foundation/Foundation.h>

@class CytrusGameInformation;

#ifdef __cplusplus
#include "core/core.h"
#include "core/hle/service/am/am.h"
#include "core/loader/loader.h"
#include "core/loader/smdh.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface CytrusGameInformationManager : NSObject {
    CytrusGameInformation * _Nullable _information;
}

-(CytrusGameInformationManager *) initWithURL:(NSURL *)url;

-(CytrusGameInformation * _Nullable) information;
@end

NS_ASSUME_NONNULL_END
