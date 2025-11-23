//
//  MultiplayerManager.h
//  Cytrus
//
//  Created by Jarrod Norwell on 23/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CytrusNetworkChatEntry;
@class CytrusRoom;
@class CytrusRoomMember;
@protocol CytrusMultiplayerManagerDelegate;

#ifdef __cplusplus
#include "common/announce_multiplayer_room.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface CytrusMultiplayerManager : NSObject
@property (nonatomic, strong) NSMutableArray<CytrusNetworkChatEntry *> *entries;
@property (nonatomic, strong) CytrusRoom * _Nullable connectedRoom;
@property (nonatomic, strong, nullable) id<CytrusMultiplayerManagerDelegate> delegate;

+(CytrusMultiplayerManager *) sharedInstance NS_SWIFT_NAME(shared());

-(NSArray<CytrusRoom *> *) availableRoomsForGameID:(NSString * _Nullable)identifier NS_SWIFT_NAME(availableRooms(for:));

-(void) connectToRoom:(CytrusRoom *)room withUsername:(NSString *)username andPassword:(NSString * _Nullable)password NS_SWIFT_NAME(connect(to:with:and:));
-(void) disconnect;
-(void) sendChatMessage:(NSString *)message;

-(void) updateWebAPIURL;
@end

NS_ASSUME_NONNULL_END
