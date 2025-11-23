//
//  CheatsManager.m
//  Cytrus
//
//  Created by Jarrod Norwell on 19/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "CheatsManager.h"

#import "Cytrus-Swift.h"

@interface CytrusCheatsManager () {
    Cheats::CheatEngine* _cheat_engine;
}
@end

@implementation CytrusCheatsManager
-(CytrusCheatsManager *) initWithIdentifier:(uint64_t)identifier {
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

-(NSArray<CytrusCheat *> *) getCheats {
    NSString *(^nsString)(std::string) = ^NSString *(std::string string) {
        return [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
    };
    
    NSMutableArray *convertedCheats = @[].mutableCopy;
    for (auto cheat : _cheat_engine->GetCheats())
        [convertedCheats addObject:[[CytrusCheat alloc] initWithEnabled:cheat->IsEnabled()
                                                                   code:nsString(cheat->GetCode())
                                                               comments:nsString(cheat->GetComments())
                                                                   name:nsString(cheat->GetName())
                                                                   type:nsString(cheat->GetType())]];
    
    return convertedCheats;
}

-(void) removeCheatAtIndex:(NSInteger)index {
    _cheat_engine->RemoveCheat(index);
}

-(void) toggleCheat:(CytrusCheat *)cheat {
    cheat.enabled = !cheat.enabled;
}

-(void) updateCheat:(CytrusCheat *)cheat atIndex:(NSInteger)index {
    auto gateway = std::make_shared<Cheats::GatewayCheat>([cheat.name UTF8String], [cheat.code UTF8String], [cheat.comments UTF8String]);
    gateway->SetEnabled(cheat.enabled);
    
    _cheat_engine->UpdateCheat(index, gateway);
}
@end
