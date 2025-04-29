
import SwiftUI

@main
struct LanguageTranslatorPOCApp: App {
    @State private var translationService = TranslationService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(translationService)
        }
    }
}
