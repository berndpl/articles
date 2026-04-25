import AVFoundation
import Observation

@Observable
@MainActor
final class ArticleSpeechSynthesizer: NSObject {
    enum State: Equatable {
        case idle
        case speaking
        case paused
    }

    struct VoiceInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let language: String
        let qualityRaw: Int

        var qualityLabel: String {
            switch qualityRaw {
            case 3: "Premium"
            case 2: "Enhanced"
            default: "Default"
            }
        }
    }

    private(set) var state: State = .idle
    var selectedVoiceID: String? {
        didSet { UserDefaults.standard.set(selectedVoiceID, forKey: "ArticleSpeechVoiceID") }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var currentHTML: String?

    var availableVoices: [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.name < rhs.name
            }
            .map { VoiceInfo(id: $0.identifier, name: $0.name, language: $0.language, qualityRaw: $0.quality.rawValue) }
    }

    var selectedVoiceName: String? {
        guard let id = selectedVoiceID else { return nil }
        return AVSpeechSynthesisVoice(identifier: id)?.name
    }

    override init() {
        self.selectedVoiceID = UserDefaults.standard.string(forKey: "ArticleSpeechVoiceID")
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ html: String) {
        let text = Self.stripHTML(html)
        guard !text.isEmpty else { return }

        if state == .paused {
            synthesizer.continueSpeaking()
            state = .speaking
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        configureAudioSession()
        currentHTML = html

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if let voiceID = selectedVoiceID {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID)
        }
        synthesizer.speak(utterance)
        state = .speaking
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }

    func toggle(_ html: String) {
        switch state {
        case .idle:
            speak(html)
        case .speaking:
            pause()
        case .paused:
            speak(html)
        }
    }

    /// Restart speech with the new voice if currently playing
    func restartIfNeeded() {
        guard let html = currentHTML, state != .idle else { return }
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        speak(html)
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil
              )
        else {
            return html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ArticleSpeechSynthesizer: @preconcurrency AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .idle
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .idle
        }
    }
}
