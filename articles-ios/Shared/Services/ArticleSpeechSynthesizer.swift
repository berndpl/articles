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
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") || $0.language.hasPrefix("de") }

        let bestQuality = voices.max(by: { $0.quality.rawValue < $1.quality.rawValue })?.quality.rawValue ?? 0

        return voices
            .filter { $0.quality.rawValue == bestQuality }
            .sorted { $0.name < $1.name }
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
        speakText(Self.readableText(from: html))
        currentHTML = html
    }

    func speak(_ markdown: String, fromParagraphIndex paragraphIndex: Int) {
        let text = Self.readableText(from: markdown, startingAtParagraphIndex: paragraphIndex)
        speakText(text)
        currentHTML = markdown
    }

    private func speakText(_ text: String) {
        guard !text.isEmpty else { return }

        if state == .paused {
            synthesizer.continueSpeaking()
            state = .speaking
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        configureAudioSession()

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

    static func readableText(from content: String, startingAtParagraphIndex paragraphIndex: Int = 0) -> String {
        let contentToRead: String
        if paragraphIndex > 0 {
            let blocks = ArticleMarkdownSegmenter.blocks(from: content)
            contentToRead = ArticleMarkdownSegmenter.markdown(from: blocks, startingAt: paragraphIndex)
        } else {
            contentToRead = content
        }

        return stripReadableMarkup(contentToRead)
    }

    private static func stripReadableMarkup(_ content: String) -> String {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            return ArticleMarkdownDocument.plainText(fromMarkdown: content)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return content.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ArticleSpeechSynthesizer: AVSpeechSynthesizerDelegate {
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
