//
//  GameInformation.m
//  Cytrus
//
//  Created by Jarrod Norwell on 18/4/2025.
//  Copyright © 2025 Jarrod Norwell. All rights reserved.
//

#import "GameInformation.h"

@implementation CoreVersion
-(CoreVersion *) initWithCoreVersion:(uint32_t)coreVersion {
    if (self = [super init]) {
        Kernel::CoreVersion version = Kernel::CoreVersion(coreVersion);
        
        self.major = version.major;
        self.minor = version.minor;
        self.revision = version.revision;
    } return self;
}
@end

@implementation GameInformation
-(GameInformation *) initWithURL:(NSURL *)url {
    if (self = [super init]) {
        const auto data = GetSMDHData([url.path UTF8String]);
        const auto publisher = Publisher(data);
        const auto regions = Regions(data);
        const auto title = Title(data);
        
        u64 program_id{0};
        auto app_loader = Loader::GetLoader([url.path UTF8String]);
        if (app_loader) {
            app_loader->ReadProgramId(program_id);
        }
        
        uint32_t defaultCoreVersion = (1 << 24) | (0 << 16) | (1 << 8);
        
        self.coreVersion = [[CoreVersion alloc] initWithCoreVersion:defaultCoreVersion];
        self.kernelMemoryMode = (KernelMemoryMode)(app_loader->LoadKernelMemoryMode().first || 0);
        self.new3DSKernelMemoryMode = (New3DSKernelMemoryMode)app_loader->LoadNew3dsHwCapabilities().first->memory_mode;
        
        self.identifier = program_id;
        if (auto icon = Icon(data); icon.size() > 0)
            self.icon = [NSData dataWithBytes:icon.data() length:48 * 48 * sizeof(uint16_t)];
        else
            self.icon = NULL;
        self.publisher = [NSString stringWithCharacters:(const unichar*)publisher.c_str() length:publisher.length()];
        self.regions = [NSString stringWithCString:regions.c_str() encoding:NSUTF8StringEncoding];
        self.title = [NSString stringWithCharacters:(const unichar*)title.c_str() length:title.length()];
    } return self;
}
@end
