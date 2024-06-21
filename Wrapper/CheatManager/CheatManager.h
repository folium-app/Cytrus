//
//  CheatManager.h
//  Limon
//
//  Created by Jarrod Norwell on 18/2/2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Cheat : NSObject
@property (nonatomic) BOOL isEnabled;
@property (nonatomic, strong) NSString *code;
@property (nonatomic, strong) NSString * _Nullable comments;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString * _Nullable type;

-(Cheat *) initWithEnabled:(BOOL)isEnabled code:(NSString *)code comments:(NSString * _Nullable)comments name:(NSString *)name type:(NSString * _Nullable)type;
@end

@interface CheatManager : NSObject {
    uint64_t _titleIdentifier;
}

-(void) loadCheats:(uint64_t)titleIdentifier;
-(void) saveCheats:(uint64_t)titleIdentifier;

-(void) addCheatWithName:(NSString *)name code:(NSString *)code comments:(NSString *)comments;
-(void) removeCheatAtIndex:(NSInteger)index;
-(void) toggleCheat:(Cheat *)cheat;
-(void) updateCheat:(Cheat *)cheat atIndex:(NSInteger)index;
-(NSArray<Cheat *> *) getCheats;
@end

NS_ASSUME_NONNULL_END
