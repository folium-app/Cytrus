//
//  CheatsManager.h
//  Cytrus
//
//  Created by Jarrod Norwell on 19/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CytrusCheat;

#ifdef __cplusplus
#include <algorithm>
#include <memory>
#include <utility>

#include "core/core.h"
#include "core/cheats/cheat_base.h"
#include "core/cheats/cheats.h"
#include "core/cheats/gateway_cheat.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface CytrusCheatsManager : NSObject {
    uint64_t _identifier;
}

-(CytrusCheatsManager *) initWithIdentifier:(uint64_t)identifier NS_SWIFT_NAME(init(with:));

-(void) loadCheats NS_SWIFT_NAME(load());
-(void) saveCheats NS_SWIFT_NAME(save());

-(NSArray<CytrusCheat *> *) getCheats NS_SWIFT_NAME(cheats());

-(void) removeCheatAtIndex:(NSInteger)index NS_SWIFT_NAME(remove(at:));
-(void) toggleCheat:(CytrusCheat *)cheat NS_SWIFT_NAME(toggle(cheat:));
-(void) updateCheat:(CytrusCheat *)cheat atIndex:(NSInteger)index NS_SWIFT_NAME(update(cheat:at:));
@end

NS_ASSUME_NONNULL_END
