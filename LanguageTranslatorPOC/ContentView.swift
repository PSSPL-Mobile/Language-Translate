import SwiftUI
import Translation
import AVFAudio
import AVFoundation
import Combine

struct ContentView: View {
    
    @Environment(TranslationService.self) var translationService
    @StateObject private var viewModel = SpeechToTextViewModel(speechToTextService: SpeechToTextService())
    
    @State private var englishText = ""
    @State private var sourceLanguage = Locale.Language(languageCode: AppConstants.englishLanguageCode, script: nil, region: AppConstants.usRegion)
    @State private var targetLanguage = Locale.Language(languageCode: AppConstants.hindiLanguageCode, script: nil, region: AppConstants.inRegion)
    
    @State private var configuration: TranslationSession.Configuration?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    @State private var textChangeSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Text(AppConstants.translationTitle)
                    .font(.headline)
            }
            .frame(height: 44)
            .background(Color(UIColor.systemGray6))
            
            // Input Section
            VStack(alignment: .leading, spacing: 0) {
                Picker(AppConstants.inputLanguagePlaceholder, selection: $sourceLanguage) {
                    ForEach(translationService.availableLanguages) { language in
                        Text(language.localizedName())
                            .tag(language.locale)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.black)
                .onChange(of: sourceLanguage) { _,  newValue in
                    configuration?.invalidate()
                    configuration = TranslationSession.Configuration(source: newValue)
                }
                
                TextField(inputPlaceholder, text: $englishText, axis: .vertical)
                    .font(.title2)
                    .padding(.horizontal, 12)
                    .padding(.trailing, sourceLanguage.languageCode == AppConstants.arabicLanguageCode ? 25 : 20)
                    .textFieldStyle(PlainTextFieldStyle())
                    .background(Color.white)
                    .cornerRadius(10)
                    .multilineTextAlignment(sourceLanguage.languageCode == AppConstants.arabicLanguageCode ? .trailing : .leading)
                    .onReceive(viewModel.$transcript) { newValue in
                        self.englishText = newValue
                        self.textChangeSubject.send(newValue)
                    }
                    .overlay(alignment: .topTrailing) {
                        Button(action: {
                            toggleRecord()
                        }) {
                            Image(systemName: isSpeaking ? Icons.stop.rawValue : Icons.mic.rawValue)
                                .foregroundColor(.black)
                                .font(.system(size: 22))
                        }
                        .padding(.horizontal, 10)
                    }
//                    .padding(.vertical)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onChange(of: englishText) { _, newValue in
                        textChangeSubject.send(newValue)
                    }
            }
            .frame(maxHeight: .infinity)
            .background(Color.white)
            .cornerRadius(15)
            .padding(10)

            
            // Output Section
            VStack(alignment: .leading, spacing: 4) {
                Picker(AppConstants.targetLanguagePlaceholder, selection: $targetLanguage) {
                    ForEach(translationService.availableLanguages) { language in
                        Text(language.localizedName())
                            .tag(language.locale)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.black)
                .onChange(of: targetLanguage) { _, newValue in
                    configuration?.invalidate()
                    configuration = TranslationSession.Configuration(target: newValue)
                }
                
                HStack {
                    Text(translationService.translatedText.isEmpty ? AppConstants.noTranslation : translationService.translatedText)
                        .italic()
                        .textSelection(.enabled)
                        .translationTask(configuration) { session in
                            do {
                                try await translationService.translate(
                                    text: englishText,
                                    using: session
                                )
                                print("Translated text: \(translationService.translatedText)")
                                setupAudioSessionForPlayback()
                                speakTranslatedText()
                            } catch {
                                translationService.translatedText = ""
                                print("Translation error: \(error.localizedDescription)")
                            }
                        }
                    
                    Spacer()
                    
                    Button {
                        setupAudioSessionForPlayback()
                        speakTranslatedText()
                    } label: {
                        Image(systemName: Icons.speaker.rawValue)
                    }
                    .disabled(translationService.translatedText.isEmpty)
                    .foregroundColor(.black)
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
            .background(Color.white)
            .cornerRadius(15)
            .padding(10)
        }
        .background(Color(UIColor.systemGray6))
        .onAppear {
            setupAudioSessionForPlayback()
            updateTranslationConfiguration()
            setupTextChangeDebounce()
        }
    }
    
    private var inputPlaceholder: String {
        let languageCode = sourceLanguage.languageCode?.identifier ?? AppConstants.englishIdentifier
        let regionCode = sourceLanguage.region?.identifier
        let fullIdentifier = [languageCode, regionCode].compactMap { $0 }.joined(separator: "-")
        
        let localizedPlaceholders: [String: String] = [
            "ar-AE": "أدخل النص",
            "zh-CN": "输入文本",
            "zh-TW": "輸入文字",
            "nl-NL": "Voer tekst in",
            "en-GB": "Enter text",
            "en-US": "Enter text",
            "fr-FR": "Entrez le texte",
            "de-DE": "Text eingeben",
            "hi-IN": "टेक्स्ट दर्ज करें",
            "id-ID": "Masukkan teks",
            "it-IT": "Inserisci il testo",
            "ja-JP": "テキストを入力",
            "ko-KR": "텍스트 입력",
            "pl-PL": "Wpisz tekst",
            "pt-BR": "Digite o texto",
            "ru-RU": "Введите текст",
            "es-ES": "Introduce texto",
            "th-TH": "ป้อนข้อความ",
            "tr-TR": "Metni girin",
            "uk-UA": "Введіть текст",
            "vi-VN": "Nhập văn bản"
        ]
        
        return localizedPlaceholders[fullIdentifier, default: "Enter text"]
    }

    
    private func setupTextChangeDebounce() {
        textChangeSubject
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { _ in
                triggerTranslation()
            }
            .store(in: &cancellables)
    }
    
    private func triggerTranslation() {
        updateTranslationConfiguration()
        viewModel.stopRecording()
        isSpeaking = false
    }
    
    private func updateTranslationConfiguration() {
        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: sourceLanguage,
                target: targetLanguage
            )
            return
        }
        configuration?.invalidate()
        viewModel.stopRecording()
        isSpeaking = false
        setupAudioSessionForPlayback()
    }
    
    private func toggleRecord() {
        isSpeaking.toggle()
        if viewModel.isRecording {
            englishText = ""
            translationService.translatedText = ""
            viewModel.stopRecording()
            setupAudioSessionForPlayback()
        } else {
            setupAudioSessionForRecording()
            viewModel.startRecording()
        }
    }
    
    private func setupAudioSessionForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("Audio session configured for recording")
        } catch {
            print("Failed to configure audio session for recording: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session for playback: \(error.localizedDescription)")
        }
    }
    
    private func speakTranslatedText() {
        guard !translationService.translatedText.isEmpty else {
            print("No text to speak")
            return
        }
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: translationService.translatedText)
        let languageCode = targetLanguage.languageCode?.identifier ?? AppConstants.hindiIdentifier
        let regionCode = targetLanguage.region?.identifier ?? AppConstants.indiaRegionIdentifier
        let voiceLanguage = "\(languageCode)-\(regionCode)"
        
        if let voice = AVSpeechSynthesisVoice(language: voiceLanguage) {
            utterance.voice = voice
            print("Using voice: \(voiceLanguage)")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: AppConstants.enUSLanguage)
            print("Voice for \(voiceLanguage) not found, falling back to en-US")
        }
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = SpeechSynthesizerDelegate.shared
        speechSynthesizer.speak(utterance)
        print("Speaking: \(translationService.translatedText)")
    }
}

class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechSynthesizerDelegate()
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Speech started")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Speech finished")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech cancelled")
    }
}

