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

@interface CheatsManager () {
    Cheats::CheatEngine* _cheat_engine;
}
@end

@implementation CheatsManager
-(CheatsManager *) initWithIdentifier:(uint64_t)identifier {
    if (self = [super init]) {
        _identifier = identifier;
        _cheat_engine = new Cheats::CheatEngine(Core::System::GetInstance());
    } return self;
}

-(void) loadCheats {
    _cheat_engine->LoadCheatFile(_identifier);
}

-(void) saveCheats {
    _cheat_engine->SaveCheatFile(_identifier);
}

-(NSArray<Cheat *> *) getCheats {
    auto cheats = _cheat_engine->GetCheats();
    NSMutableArray *convertedCheats = @[].mutableCopy;
    for (const auto& cheat : cheats)
        [convertedCheats addObject:[[Cheat alloc] initWithEnabled:cheat->IsEnabled()
                                                             name:[NSString stringWithCString:cheat->GetName().c_str() encoding:NSUTF8StringEncoding]
                                                             code:[NSString stringWithCString:cheat->GetCode().c_str() encoding:NSUTF8StringEncoding]
                                                         comments:[NSString stringWithCString:cheat->GetComments().c_str() encoding:NSUTF8StringEncoding]]];
    
    return convertedCheats;
}

-(void) removeCheatAtIndex:(NSInteger)index {
    _cheat_engine->RemoveCheat(index);
}

-(void) toggleCheat:(Cheat *)cheat {
    cheat.enabled = !cheat.enabled;
}

-(void) updateCheat:(Cheat *)cheat atIndex:(NSInteger)index {
    auto gateway = std::make_shared<Cheats::GatewayCheat>(cheat.name.UTF8String, cheat.code.UTF8String, cheat.comments.UTF8String);
    gateway->SetEnabled(cheat.enabled);
    
    _cheat_engine->UpdateCheat(index, gateway);
}
@end
