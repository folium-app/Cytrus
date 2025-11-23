//
//  GameInformationManager.mm
//  Cytrus
//
//  Created by Jarrod Norwell on 15/7/2025.
//

#import "GameInformationManager.h"

#import "Cytrus-Swift.h"

namespace {
    std::vector<uint8_t> GetSMDHData(const std::unique_ptr<Loader::AppLoader>& loader) {
        if (!loader)
            return std::vector<uint8_t>(0, 0);
        
        u64 program_id{0};
        loader->ReadProgramId(program_id);
        
        std::vector<uint8_t> smdh = [program_id, &loader]() -> std::vector<u8> {
            std::vector<uint8_t> original_smdh;
            loader->ReadIcon(original_smdh);
            
            if (program_id < 0x00040000'00000000 || program_id > 0x00040000'FFFFFFFF)
                return original_smdh;
            
            std::string update_path = Service::AM::GetTitleContentPath(Service::FS::MediaType::SDMC, program_id + 0x0000000E'00000000);
            
            if (!FileUtil::Exists(update_path))
                return original_smdh;
            
            std::unique_ptr<Loader::AppLoader> update_loader = Loader::GetLoader(update_path);
            
            if (!update_loader)
                return original_smdh;
            
            std::vector<uint8_t> update_smdh;
            update_loader->ReadIcon(update_smdh);
            return update_smdh;
        }();
        
        return smdh;
    }
    
    std::vector<uint16_t> Icon(std::vector<uint8_t> smdh_data) {
        if (!Loader::IsValidSMDH(smdh_data))
            return std::vector<uint16_t>(0, 0);
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        std::vector<uint16_t> icon_data = smdh.GetIcon(true);
        return icon_data;
    }
    
    
    std::u16string Publisher(std::vector<uint8_t> smdh_data) {
        Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
        
        if (!Loader::IsValidSMDH(smdh_data))
            return {};
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        char16_t* publisher = reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].publisher.data());
        return publisher;
    }
    
    std::string Regions(std::vector<uint8_t> smdh_data) {
        if (!Loader::IsValidSMDH(smdh_data))
            return "Invalid region";
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        using GameRegion = Loader::SMDH::GameRegion;
        static const std::map<GameRegion, const char*> regions_map = {
            {GameRegion::Japan, "Japan"},   {GameRegion::NorthAmerica, "North America"},
            {GameRegion::Europe, "Europe"}, {GameRegion::Australia, "Australia"},
            {GameRegion::China, "China"},   {GameRegion::Korea, "Korea"},
            {GameRegion::Taiwan, "Taiwan"}};
        
        std::vector<GameRegion> regions = smdh.GetRegions();
        if (regions.empty())
            return "Invalid region";
        
        const bool region_free = std::all_of(regions_map.begin(), regions_map.end(), [&regions](const auto& it) {
            return std::find(regions.begin(), regions.end(), it.first) != regions.end();
        });
        
        if (region_free)
            return "Region Free";
        
        const std::string separator = ", ";
        std::string result = regions_map.at(regions.front());
        for (auto region = ++regions.begin(); region != regions.end(); ++region)
            result += separator + regions_map.at(*region);
        
        return result;
    }
    
    std::u16string Title(std::vector<uint8_t> smdh_data) {
        Loader::SMDH::TitleLanguage language = Loader::SMDH::TitleLanguage::English;
        
        if (!Loader::IsValidSMDH(smdh_data))
            return {};
        
        Loader::SMDH smdh;
        memcpy(&smdh, smdh_data.data(), sizeof(Loader::SMDH));
        
        std::u16string title{reinterpret_cast<char16_t*>(smdh.titles[static_cast<int>(language)].long_title.data())};
        return title;
    }
    
    bool IsSystemTitle(std::string physical_name) {
        std::unique_ptr<Loader::AppLoader> loader = Loader::GetLoader(physical_name);
        if (!loader)
            return false;
        
        u64 program_id{0};
        loader->ReadProgramId(program_id);
        return ((program_id >> 32) & 0xFFFFFFFF) == 0x00040010;
    }
}

@implementation CytrusGameInformationManager
-(CytrusGameInformationManager *) initWithURL:(NSURL *)url {
    if (self = [super init]) {
        NSString *(^nsString)(std::string) = ^NSString *(std::string string) {
            return [NSString stringWithCString:string.c_str() encoding:NSUTF8StringEncoding];
        };
        
        NSString *(^nsStringFromCharacters)(std::u16string) = ^NSString *(std::u16string string) {
            return [NSString stringWithCharacters:(const unichar*)string.c_str() length:string.length()];
        };
        
        uint64_t program_id{0};
        auto app_loader = Loader::GetLoader([url.path UTF8String]);
        if (app_loader) {
            app_loader->ReadProgramId(program_id);
            
            auto data = GetSMDHData(app_loader);
            auto publisher = Publisher(data);
            auto regions = Regions(data);
            auto title = Title(data);
            
            auto icon = Icon(data);
            
            _information = [[CytrusGameInformation alloc] initWithIdentifier:program_id
                                                            kernelMemoryMode:(CytrusKernelMemoryMode)(app_loader->LoadKernelMemoryMode().first || 0)
                                                      new3DSKernelMemoryMode:(CytrusNew3DSKernelMemoryMode)(app_loader->LoadNew3dsHwCapabilities().first->memory_mode)
                                                                   publisher:nsStringFromCharacters(publisher.c_str())
                                                                     regions:nsString(regions.c_str())
                                                                       title:nsStringFromCharacters(title.c_str())
                                                                        icon:icon.size() > 0 ? [NSData dataWithBytes:icon.data() length:48 * 48 * sizeof(uint16_t)] : NULL];
        } else
            _information = NULL;
    } return self;
}

-(CytrusGameInformation * _Nullable) information {
    return _information;
}
@end
