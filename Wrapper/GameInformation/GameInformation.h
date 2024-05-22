//
//  GameInformation.h
//  Limon
//
//  Created by Jarrod Norwell on 1/20/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Information : NSObject
@property (nonatomic, strong) NSData *iconData;
@property (nonatomic) BOOL isSystem;
@property (nonatomic, strong) NSString *publisher, *regions, *title;

-(Information *) initWithIconData:(NSData *)iconData isSystem:(BOOL)isSystem publisher:(NSString *)publisher
                          regions:(NSString *)regions title:(NSString *)title;
@end

@interface GameInformation : NSObject
+(GameInformation *) sharedInstance NS_SWIFT_NAME(shared());

-(Information *) informationForGame:(NSURL *)url NS_SWIFT_NAME(information(for:));
@end

NS_ASSUME_NONNULL_END
