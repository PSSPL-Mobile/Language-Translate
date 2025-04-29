
import Foundation
import SwiftUI
import Combine
import AVFoundation
import Translation


 class TranslationViewModel: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var englishText: String = ""
    @Published var sourceLanguage: Locale.Language
    @Published var targetLanguage: Locale.Language
    @Published var configuration: TranslationSession.Configuration?
    @Published var isSpeaking: Bool = false
    
    let translationService: TranslationService
    var speechSynthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()
    private var textChangeSubject = PassthroughSubject<String, Never>()
    private let viewModel = SpeechToTextViewModel(speechToTextService: SpeechToTextService())
    
    @MainActor
    init(translationService: TranslationService) {
        self.translationService = translationService
        self.sourceLanguage = Locale.Language(languageCode: AppConstants.englishLanguageCode, script: nil, region: AppConstants.usRegion)
        self.targetLanguage = Locale.Language(languageCode: AppConstants.hindiLanguageCode, script: nil, region: AppConstants.inRegion)
        super.init()
        self.speechSynthesizer.delegate = self
        setupTextChangeDebounce()
    }
    
    func updateSourceLanguage(_ language: Locale.Language) {
        sourceLanguage = language
        configuration?.invalidate()
        configuration = TranslationSession.Configuration(source: language)
    }
    
    func updateTargetLanguage(_ language: Locale.Language) {
        targetLanguage = language
        configuration?.invalidate()
        configuration = TranslationSession.Configuration(target: language)
    }
    
    func handleTextChange(_ text: String) {
        englishText = text
        textChangeSubject.send(text)
    }
    
    @MainActor
    private func setupTextChangeDebounce() {
        textChangeSubject
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.triggerTranslation()
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func triggerTranslation() {
        updateTranslationConfiguration()
        viewModel.stopRecording()
        isSpeaking = false
    }
    
    @MainActor
    func toggleRecord() {
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
    
    func speakTranslatedText() {
        guard !translationService.translatedText.isEmpty else { return }
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: translationService.translatedText)
        let voiceLanguage = "\(targetLanguage.languageCode?.identifier ?? "hi")-\(targetLanguage.region?.identifier ?? "IN")"
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    @MainActor
    private func updateTranslationConfiguration() {
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
        } else {
            configuration?.invalidate()
        }
        viewModel.stopRecording()
        isSpeaking = false
        setupAudioSessionForPlayback()
    }
    
    private func setupAudioSessionForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    private func setupAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Playback session error: \(error)")
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
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
