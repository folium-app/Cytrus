//
//  CheatManager.mm
//  Limon
//
//  Created by Jarrod Norwell on 18/2/2024.
//

#import "CheatManager.h"

#include "common/string_util.h"
#include "core/core.h"
#include "core/cheats/cheat_base.h"
#include "core/cheats/gateway_cheat.h"

@implementation Cheat
-(Cheat *) initWithEnabled:(BOOL)isEnabled code:(NSString *)code comments:(NSString * _Nullable)comments name:(NSString *)name type:(NSString * _Nullable)type {
    if (self = [super init]) {
        self.isEnabled = isEnabled;
        self.code = code;
        self.comments = comments;
        self.name = name;
        self.type = type;
    } return self;
}
@end

std::unique_ptr<Cheats::CheatEngine> engine;

@implementation CheatManager
-(CheatManager *) init {
    if (self = [super init]) {
        engine = std::make_unique<Cheats::CheatEngine>(Core::System::GetInstance());
    } return self;
}

-(void) loadCheats:(uint64_t)titleIdentifier {
    _titleIdentifier = titleIdentifier;
    engine->LoadCheatFile(_titleIdentifier);
}

-(void) saveCheats:(uint64_t)titleIdentifier {
    _titleIdentifier = titleIdentifier;
    engine->SaveCheatFile(_titleIdentifier);
}

-(NSArray<Cheat *> *) getCheats {
    NSMutableArray<Cheat *> *cheats = @[].mutableCopy;
    
    for (auto& cheat : engine->GetCheats())
        [cheats addObject:[[Cheat alloc] initWithEnabled:cheat->IsEnabled()
                                                    code:[NSString stringWithCString:cheat->GetCode().c_str() encoding:NSUTF8StringEncoding]
                                                comments:[NSString stringWithCString:cheat->GetComments().c_str() encoding:NSUTF8StringEncoding]
                                                    name:[NSString stringWithCString:cheat->GetName().c_str() encoding:NSUTF8StringEncoding]
                                                    type:[NSString stringWithCString:cheat->GetType().c_str() encoding:NSUTF8StringEncoding]]];
    
    return cheats;
}

-(void) addCheatWithName:(NSString *)name code:(NSString *)code comments:(NSString *)comments {
    const auto code_lines = Common::SplitString(std::string([code UTF8String]), '\n');

    for (int i = 0; i < code_lines.size(); ++i) {
        Cheats::GatewayCheat::CheatLine cheat_line(code_lines[i]);
        if (!cheat_line.valid) {
            NSLog(@"invalid cheat line = %i", i + 1);
        }
    }
    
    
    std::shared_ptr<Cheats::GatewayCheat> cppCheat;
    cppCheat = std::make_shared<Cheats::GatewayCheat>(std::string([name UTF8String]), std::string([code UTF8String]), std::string([comments UTF8String]));
    
    std::shared_ptr<Cheats::CheatBase>* cheatBase;
    cheatBase = reinterpret_cast<std::shared_ptr<Cheats::CheatBase>*>(cppCheat.get());
    
    engine->AddCheat(std::move(*cheatBase));
}

-(void) removeCheatAtIndex:(NSInteger)index {
    engine->RemoveCheat(index);
    [self saveCheats:_titleIdentifier];
}

-(void) toggleCheat:(Cheat *)cheat {
    cheat.isEnabled = !cheat.isEnabled;
}

-(void) updateCheat:(Cheat *)cheat atIndex:(NSInteger)index {
    std::shared_ptr<Cheats::GatewayCheat> cppCheat;
    cppCheat = std::make_shared<Cheats::GatewayCheat>([cheat.name UTF8String], [cheat.code UTF8String], [cheat.comments UTF8String]);
    cppCheat->SetEnabled(cheat.isEnabled);
    engine->UpdateCheat(index, cppCheat);
}
@end
