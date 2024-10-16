import Foundation

public struct WMFFeatureConfigResponse: Codable {
    public struct IOS: Codable {
        
        public struct YearInReview: Codable {
            
            public struct PersonalizedSlides: Codable {
                let readCount: SlideSettings
                let editCount: SlideSettings
            }
            
            public struct SlideSettings: Codable {
                public let isEnabled: Bool
            }
            
            public let isEnabled: Bool
            public let countryCodes: [String]
            public let primaryAppLanguageCodes: [String]
            public let dataPopulationStartDateString: String
            public let dataPopulationEndDateString: String
            public let personalizedSlides: PersonalizedSlides
        }

        let version: Int

        public let yir: YearInReview
    }
    
    public let ios: [IOS]
    var cachedDate: Date?
    
    private let currentFeatureConfigVersion = 1
    
    public init(ios: [WMFFeatureConfigResponse.IOS], cachedDate: Date? = nil) {
        self.ios = ios
        self.cachedDate = cachedDate
    }
    
    public init(from decoder: Decoder) throws {
        
        // Custom decoding to filter out invalid versions
        
        let overallContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        var versionContainer = try overallContainer.nestedUnkeyedContainer(forKey: .ios)
        var iosContainer = try overallContainer.nestedUnkeyedContainer(forKey: .ios)
        
        var validConfigs: [IOS] = []
        while !versionContainer.isAtEnd {
            
            let wmfVersion: WMFConfigVersion
            let config: IOS
            do {
                wmfVersion = try versionContainer.decode(WMFConfigVersion.self)
            } catch {
                // Skip
                _ = try? versionContainer.decode(WMFDiscardedElement.self)
                _ = try? iosContainer.decode(WMFDiscardedElement.self)
                continue
            }
            
            guard wmfVersion.version == currentFeatureConfigVersion else {
                // Skip
                _ = try? iosContainer.decode(WMFDiscardedElement.self)
                continue
            }
                
            do {
                config = try iosContainer.decode(IOS.self)
            } catch {
                // Skip
                _ = try? iosContainer.decode(WMFDiscardedElement.self)
                continue
            }
            
            validConfigs.append(config)
        }
        
        self.ios = validConfigs
        self.cachedDate = try? overallContainer.decode(Date.self, forKey: .cachedDate)
    }
}
