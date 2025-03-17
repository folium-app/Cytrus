//
//  CheatsManager.h
//  Cytrus
//
//  Created by Jarrod Norwell on 19/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface Cheat : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSString *name, *code, *comments;

-(Cheat *) initWithEnabled:(BOOL)enabled name:(NSString *)name code:(NSString *)code comments:(NSString *)comments;
@end

@interface CheatsManager : NSObject
+(CheatsManager *) sharedInstance NS_SWIFT_NAME(shared());

-(void) loadCheats:(uint64_t)titleIdentifier;
-(void) saveCheats:(uint64_t)titleIdentifier;

-(NSArray<Cheat *> *) getCheats;

-(void) removeCheatAtIndex:(NSInteger)index;
-(void) toggleCheat:(Cheat *)cheat;
-(void) updateCheat:(Cheat *)cheat atIndex:(NSInteger)index;
@end

NS_ASSUME_NONNULL_END
