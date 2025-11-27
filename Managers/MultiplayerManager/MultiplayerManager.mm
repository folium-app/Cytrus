//
//  MultiplayerManager.m
//  Cytrus
//
//  Created by Jarrod Norwell on 23/10/2024.
//  Copyright © 2024 Jarrod Norwell. All rights reserved.
//

#import "MultiplayerManager.h"

#import "Cytrus-Swift.h"

#include <array>
#include <iostream>
#include <memory>

#include "common/announce_multiplayer_room.h"
#include "core/core.h"
#include "core/hle/service/cfg/cfg.h"
#include "network/announce_multiplayer_session.h"
#include "network/network.h"
#include "network/network_settings.h"
#include "network/room.h"

std::shared_ptr<Network::AnnounceMultiplayerSession> session;
std::weak_ptr<Network::AnnounceMultiplayerSession> w_session;

@implementation CytrusMultiplayerManager
-(CytrusMultiplayerManager *) init {
    if (self = [super init]) {
        if (NSString *webAPIURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"cytrus.v1.35.webAPIURL"])
            NetSettings::values.web_api_url = std::string{[webAPIURL UTF8String]};
        Network::Init();
        
        session = std::make_shared<Network::AnnounceMultiplayerSession>();
        
        _entries = @[].mutableCopy;
    } return self;
}

+(CytrusMultiplayerManager *) sharedInstance {
    static CytrusMultiplayerManager *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(NSArray<CytrusRoom *> *) availableRoomsForGameID:(NSString * _Nullable)identifier {
    if (const auto& session_ptr = session.get()) {
        NSString *(^nsString)(std::string) = ^NSString *(std::string string) {
            return [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
        };
        
        NSString *(^nsStringFromArray)(uint8_t*, size_t) = ^NSString *(uint8_t* bytes, size_t size) {
            return [[NSString alloc] initWithBytes:bytes length:size encoding:NSUTF8StringEncoding];
        };
        
        NSMutableArray<CytrusRoom *> *rooms = @[].mutableCopy;
        for (auto room : session_ptr->GetRoomList()) {
            NSString *iden = [[[NSNumber numberWithUnsignedLongLong:room.preferred_game_id] stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if ([iden isEqualToString:[identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]]) {
                NSMutableArray<CytrusRoomMember *> *members = @[].mutableCopy;
                for (auto member : room.members)
                    [members addObject:[[CytrusRoomMember alloc] initWithAvatarURL:nsString(member.avatar_url)
                                                                          gameName:nsString(member.game_name)
                                                                        macAddress:nsStringFromArray(member.mac_address.data(),
                                                                                                     member.mac_address.size())
                                                                          nickname:nsString(member.nickname)
                                                                          username:nsString(member.username)
                                                                            gameID:member.game_id]];
                
                [rooms addObject:[[CytrusRoom alloc] initWithDetails:nsString(room.description)
                                                                  id:nsString(room.id)
                                                                  ip:nsString(room.ip)
                                                                name:nsString(room.name)
                                                               owner:nsString(room.owner)
                                                       preferredGame:nsString(room.preferred_game)
                                                           verifyUID:nsString(room.verify_UID)
                                                                port:room.port
                                                      maximumPlayers:room.max_player
                                                          netVersion:room.net_version
                                                     numberOfPlayers:(uint32_t)room.members.size()
                                                     preferredGameID:room.preferred_game_id
                                                      passwordLocked:room.has_password
                                                               state:CytrusNetworkRoomMemberStateIdle
                                                             members:members]];
            }
        }
        return rooms;
    }
    
    return @[];
}

-(void) connectToRoom:(CytrusRoom *)room withUsername:(NSString *)username andPassword:(NSString * _Nullable)password {
    if (_connectedRoom)
        [self disconnect];
    
    std::string password_str{};
    if (password)
        password_str = std::string{[password UTF8String]};
    
    NSString *(^nsString)(std::string) = ^NSString *(std::string string) {
        return [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
    };
    
    if (auto room_member = Network::GetRoomMember().lock()) {
        if (_delegate) {
            room_member->BindOnChatMessageRecieved([self, nsString](const Network::ChatEntry& entry) {
                CytrusNetworkChatEntry *chatEntry = [[CytrusNetworkChatEntry alloc] initWithNickname:nsString(entry.nickname)
                                                                                        username:nsString(entry.username)
                                                                                         message:nsString(entry.message)];
                
                [_entries addObject:chatEntry];
                [_delegate didReceiveChatEntry:chatEntry];
            });
            
            room_member->BindOnError([self](const Network::RoomMember::Error& error) {
                [_delegate didReceiveError:static_cast<CytrusNetworkRoomMemberError>(error)];
            });
            
            room_member->BindOnStateChanged([self, room](const Network::RoomMember::State& state) {
                room.state = (CytrusNetworkRoomMemberState)state;
                if (state == Network::RoomMember::State::Joined)
                    _connectedRoom = room;
                [_delegate didReceiveState:static_cast<CytrusNetworkRoomMemberState>(state)];
            });
        }
        
        room_member->Join(std::string{[username UTF8String]},
                          Service::CFG::GetConsoleIdHash(Core::System::GetInstance()),
                          [room.ip UTF8String],
                          room.port,
                          0,
                          Network::NoPreferredMac,
                          password_str);
    }
}

-(void) disconnect {
    if (auto room_member = Network::GetRoomMember().lock(); room_member->IsConnected())
        room_member->Leave();
    [_entries removeAllObjects];
    _connectedRoom = NULL;
}

-(void) sendChatMessage:(NSString *)message {
    if (auto room_member = Network::GetRoomMember().lock(); room_member->IsConnected())
        room_member->SendChatMessage(std::string{[message UTF8String]});
}

-(void) updateWebAPIURL {
    Network::Shutdown();
    if (NSString *webAPIURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"cytrus.v1.35.webAPIURL"])
        NetSettings::values.web_api_url = std::string{[webAPIURL UTF8String]};
    Network::Init();
}
@end
