

import Foundation
import Translation

@Observable
class TranslationService {
    var translatedText = ""
    var availableLanguages: [AvailableLanguage] = []
    
    init() {
        getSupportedLanguages()
    }
    
    func getSupportedLanguages() {
        Task { @MainActor in
            let supportedLanguages = await LanguageAvailability().supportedLanguages
            availableLanguages = supportedLanguages.map { locale in
                AvailableLanguage(locale: locale)
            }
            .sorted()
        }
    }
    
    func translate(text: String, using session: TranslationSession) async throws {
        let response = try await session.translate(text)
        translatedText = response.targetText
    }
}
