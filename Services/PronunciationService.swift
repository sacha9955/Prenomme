import AVFoundation

@Observable
final class PronunciationService: @unchecked Sendable {
    static let shared = PronunciationService()

    private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var proxy: SynthProxy?

    private init() {
        let p = SynthProxy { [weak self] in self?.isSpeaking = false }
        proxy = p
        synthesizer.delegate = p
    }

    func speak(_ name: String, locale: String?) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: name)
        utterance.voice = AVSpeechSynthesisVoice(language: locale ?? "fr-FR")
        utterance.rate = 0.45
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// Delegate must be NSObject — isolated in a private class so PronunciationService stays clean.
private final class SynthProxy: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinished()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinished()
    }
}
