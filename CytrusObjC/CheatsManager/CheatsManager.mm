//
//  CheatsManager.m
//  Cytrus
//
//  Created by Jarrod Norwell on 19/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "CheatsManager.h"

#include "core/core.h"
#include "core/cheats/cheat_base.h"
#include "core/cheats/cheats.h"
#include "core/cheats/gateway_cheat.h"

static Cheats::CheatEngine& GetEngine() {
    Core::System& system{Core::System::GetInstance()};
    return system.CheatEngine();
}

@implementation Cheat
-(Cheat *) initWithEnabled:(BOOL)enabled name:(NSString *)name code:(NSString *)code comments:(NSString *)comments {
    if (self = [super init]) {
        self.enabled = enabled;
        self.name = name;
        self.code = code;
        self.comments = comments;
    } return self;
}
@end

@implementation CheatsManager
+(CheatsManager *) sharedInstance {
    static CheatsManager *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) loadCheats:(uint64_t)titleIdentifier {
    GetEngine().LoadCheatFile(titleIdentifier);
}

-(void) saveCheats:(uint64_t)titleIdentifier {
    GetEngine().SaveCheatFile(titleIdentifier);
}

-(NSArray<Cheat *> *) getCheats {
    auto cheats = GetEngine().GetCheats();
    NSMutableArray *convertedCheats = @[].mutableCopy;
    for (const auto& cheat : cheats)
        [convertedCheats addObject:[[Cheat alloc] initWithEnabled:cheat->IsEnabled()
                                                             name:[NSString stringWithCString:cheat->GetName().c_str() encoding:NSUTF8StringEncoding]
                                                             code:[NSString stringWithCString:cheat->GetCode().c_str() encoding:NSUTF8StringEncoding]
                                                         comments:[NSString stringWithCString:cheat->GetComments().c_str() encoding:NSUTF8StringEncoding]]];
    
    return convertedCheats;
}

-(void) toggleCheat:(Cheat *)cheat {
    cheat.enabled = !cheat.enabled;
}

-(void) updateCheat:(Cheat *)cheat atIndex:(NSInteger)index {
    auto gateway = std::make_shared<Cheats::GatewayCheat>(cheat.name.UTF8String, cheat.code.UTF8String, cheat.comments.UTF8String);
    gateway->SetEnabled(cheat.enabled);
    
    GetEngine().UpdateCheat(index, gateway);
}
@end
