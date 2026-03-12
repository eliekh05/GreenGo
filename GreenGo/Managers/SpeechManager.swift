import AVFoundation
import Speech

// MARK: - SpeechManager
// iOS 26 beta root cause: Swift 6 stamps every closure with the isolation of
// the enclosing function. Any closure created inside @MainActor code that is
// later called on a background thread (TCC, CMPedometer, AVAudioEngine tap,
// SFSpeech recognition) trips _swift_task_checkIsolatedSwift at delivery time.
//
// SOLUTION: ALL framework callback registrations (requestAuthorization,
// requestRecordPermission, recognitionTask, AND installTap) must be created
// inside non-isolated _SpeechRelay methods. SpeechManager only handles
// main-thread state; all Apple-framework interactions live in the relay.

@MainActor
final class SpeechManager: NSObject, ObservableObject {

    @Published var isListening    = false
    @Published var isPreparing    = false
    @Published var isSpeaking     = false
    @Published var recognizedText = ""
    @Published var errorMessage:  String?

    private let synthesizer:   AVSpeechSynthesizer
    private var synthDelegate: _SynthDelegate?
    let relay:                 _SpeechRelay
    private var recognizer:    SFSpeechRecognizer?
    private var isStopping     = false

    override init() {
        let r = _SpeechRelay()
        relay = r
        synthesizer = AVSpeechSynthesizer()
        super.init()
        r.owner = self
        let d = _SynthDelegate()
        d.owner = self
        synthDelegate = d
        synthesizer.delegate = d
    }

    // MARK: - TTS
    func speak(text: String, bcp47: String) {
        stopListening()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: bcp47)
        synthesizer.speak(utt)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Recognition
    func startListening(locale preferredLocale: Locale? = nil) {
        guard !isListening, !isPreparing else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isPreparing    = true
        errorMessage   = nil
        recognizedText = ""

        let preferred = preferredLocale ?? Locale.autoupdatingCurrent
        recognizer = chooseRecognizer(preferred: preferred)

        guard recognizer != nil else {
            errorMessage = "Speech recognition is unavailable for this language."
            isPreparing  = false
            return
        }
        guard recognizer!.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable."
            isPreparing  = false
            return
        }
        relay.requestSpeechAuthorization()
    }

    // MARK: - Relay callbacks (all called on main queue by relay)
    func handleAuthAuthorized()  { relay.requestMicrophonePermission() }
    func handleAuthDenied()      { errorMessage = "Speech recognition not authorized."; isPreparing = false }
    func handleMicDenied()       { errorMessage = "Microphone access not authorized."; isPreparing = false }

    func handleMicGranted() {
        guard !isListening else { isPreparing = false; return }
        relay.cancelAll()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            isPreparing  = false
            return
        }

        guard let recognizer else { isPreparing = false; return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults  = true
        req.taskHint                    = .dictation
        req.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) { req.addsPunctuation = true }

        // Both recognitionTask AND installTap closures created inside relay (non-isolated)
        let started = relay.startAudio(recognizer: recognizer, request: req)
        if let err = started {
            errorMessage = err
            isPreparing  = false
            stopListening()
            return
        }
        isListening = true
        isPreparing = false
    }

    func handleRecognitionResult(text: String?, done: Bool) {
        if let text { recognizedText = text }
        if done { stopListening() }
    }

    func handleEngineError(_ msg: String) {
        errorMessage = msg
        isListening  = false
        isPreparing  = false
        stopListening()
    }

    func stopListening() {
        guard !isStopping else { return }
        isStopping = true
        defer { isStopping = false; isPreparing = false }
        relay.cancelAll()
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Locale helpers
    private func chooseRecognizer(preferred: Locale) -> SFSpeechRecognizer? {
        let supported = SFSpeechRecognizer.supportedLocales()
        guard !supported.isEmpty else { return nil }
        for candidate in [preferred, Locale.autoupdatingCurrent] {
            let id = normalizedID(candidate.identifier)
            if let exact = supported.first(where: { normalizedID($0.identifier) == id }) {
                return SFSpeechRecognizer(locale: exact)
            }
            let lang = candidate.language.languageCode?.identifier.lowercased() ?? ""
            if !lang.isEmpty,
               let byLang = supported.first(where: {
                   ($0.language.languageCode?.identifier.lowercased() ?? "") == lang
               }) { return SFSpeechRecognizer(locale: byLang) }
        }
        return SFSpeechRecognizer(locale: supported.first ?? preferred)
    }

    private func normalizedID(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

// MARK: - _SpeechRelay (NOT @MainActor)
// Every Apple framework callback closure is created here, in non-isolated context.
// Swift 6 does not stamp non-isolated closures with @MainActor isolation,
// so background-queue delivery never trips _swift_task_checkIsolatedSwift.
final class _SpeechRelay: @unchecked Sendable {
    nonisolated(unsafe) weak var owner: SpeechManager?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?
    private var audioEngine:        AVAudioEngine?
    private var hasInstalledTap     = false

    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized { self.owner?.handleAuthAuthorized() }
                else                    { self.owner?.handleAuthDenied() }
            }
        }
    }

    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { self.owner?.handleMicGranted() }
                    else       { self.owner?.handleMicDenied()  }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { self.owner?.handleMicGranted() }
                    else       { self.owner?.handleMicDenied()  }
                }
            }
        }
    }

    // Returns nil on success, error string on failure.
    // installTap closure created here — non-isolated — safe for RealtimeMessenger delivery.
    func startAudio(recognizer: SFSpeechRecognizer,
                    request: SFSpeechAudioBufferRecognitionRequest) -> String? {
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let done = (error != nil || result?.isFinal == true)
            DispatchQueue.main.async {
                self.owner?.handleRecognitionResult(text: text, done: done)
            }
        }

        let engine    = AVAudioEngine()
        audioEngine   = engine
        let inputNode = engine.inputNode
        engine.prepare()

        let fmt = inputNode.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else {
            return "Microphone format unavailable (sampleRate=\(fmt.sampleRate))."
        }

        // installTap closure created in non-isolated context — safe on RealtimeMessenger
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak request] buf, _ in
            request?.append(buf)
        }
        hasInstalledTap = true

        do {
            try engine.start()
            return nil
        } catch {
            return "Audio engine failed: \(error.localizedDescription)"
        }
    }

    func cancelAll() {
        if let engine = audioEngine {
            if hasInstalledTap { engine.inputNode.removeTap(onBus: 0) }
            engine.stop()
            audioEngine = nil
        }
        hasInstalledTap = false
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - _SynthDelegate (NOT @MainActor)
private final class _SynthDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    nonisolated(unsafe) weak var owner: SpeechManager?

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart _: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.isSpeaking = true }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.isSpeaking = false }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.isSpeaking = false }
    }
}
