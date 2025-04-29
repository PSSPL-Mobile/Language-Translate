
import Foundation

struct AppConstants {
    static let translationTitle = "Translation"
    static let inputLanguagePlaceholder = "Input Language"
    static let targetLanguagePlaceholder = "Target Language"
    static let noTranslation = "No translation"
    static let englishIdentifier = "en"
    static let hindiIdentifier = "hi"
    static let indiaRegionIdentifier = "IN"
    static let enUSLanguage = "en-US"
    
    static let englishLanguageCode: Locale.LanguageCode = "en"
    static let hindiLanguageCode: Locale.LanguageCode = "hi"
    static let arabicLanguageCode: Locale.LanguageCode = "ar"
    static let usRegion: Locale.Region = "US"
    static let inRegion: Locale.Region = "IN"
}

enum Icons: String {
    case mic = "mic"
    case stop = "stop.circle"
    case speaker = "speaker.wave.2.bubble"
}
