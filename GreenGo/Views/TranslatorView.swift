import SwiftUI
@preconcurrency import Translation
import AVFoundation

// MARK: - TranslatorEngine
// @Observable class marked @MainActor so all properties are main-actor isolated.
// TranslationSession is created via the .translationTask modifier on a hidden view
// and stored here — because both the modifier callback AND this class share the
// same @MainActor isolation, Swift 6 sees zero actor crossing.

@MainActor
@Observable
final class TranslatorEngine {

    var inputText      = ""
    var translatedText = ""
    var isTranslating  = false
    var errorMessage:  String?
    var selectedIndex  = 0   // Arabic — index 0 in official list

    // Toggling this triggers the hidden view's .translationTask
    var config: TranslationSession.Configuration?

    // Session handed to us by .translationTask — same actor, no crossing
    private var session: TranslationSession?

    // TTS
    private let synth  = AVSpeechSynthesizer()
    private var box:   SynthBox?
    var isSpeaking     = false

    // Official Apple Translation supported languages (iOS 17+)
    // Source: developer.apple.com/documentation/translation
    // Hindi, Bengali, Urdu, Marathi, Telugu, Tamil are NOT supported by Apple Translation
    let languages: [(name: String, appleID: String, bcp47: String)] = [
        ("Arabic",               "ar",      "ar-SA"),
        ("Chinese Simplified",   "zh-Hans", "zh-CN"),
        ("Chinese Traditional",  "zh-Hant", "zh-TW"),
        ("Dutch",                "nl",      "nl-NL"),
        ("French",               "fr",      "fr-FR"),
        ("German",               "de",      "de-DE"),
        ("Indonesian",           "id",      "id-ID"),
        ("Italian",              "it",      "it-IT"),
        ("Japanese",             "ja",      "ja-JP"),
        ("Korean",               "ko",      "ko-KR"),
        ("Polish",               "pl",      "pl-PL"),
        ("Portuguese",           "pt",      "pt-BR"),
        ("Russian",              "ru",      "ru-RU"),
        ("Spanish",              "es",      "es-ES"),
        ("Thai",                 "th",      "th-TH"),
        ("Turkish",              "tr",      "tr-TR"),
        ("Ukrainian",            "uk",      "uk-UA"),
        ("Vietnamese",           "vi",      "vi-VN"),
    ]

    var currentLang: (name: String, appleID: String, bcp47: String) {
        languages[selectedIndex]
    }

    func setupSynthBox() {
        let b    = SynthBox()
        b.onFinish = { [weak self] in self?.isSpeaking = false }
        box          = b
        synth.delegate = b
    }

    // Called by the hidden SessionBridge view once it receives the session
    func receive(session: TranslationSession) {
        self.session = session
    }

    // AIA: Get_Translation button tap
    func triggerTranslation() {
        let q = inputText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isTranslating  = true
        errorMessage   = nil
        translatedText = ""
        stopSpeaking()
        // Setting config triggers SessionBridge.translationTask below
        config = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: currentLang.appleID)
        )
    }

    // Called by SessionBridge after session is ready.
    // @MainActor ensures all property access is on the main actor.
    // session.translate() is async but nonisolated so calling it from
    // @MainActor is fine — Swift 6 allows awaiting nonisolated async
    // methods from an actor context.
    @MainActor
    func runTranslation() async {
        guard let session else { isTranslating = false; return }
        let q = inputText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { isTranslating = false; return }
        do {
            let result     = try await session.translate(q)
            translatedText = result.targetText
            errorMessage   = nil
            isTranslating  = false
            speakTranslation()                // AIA: GotTranslation → TTS auto-speaks
        } catch {
            errorMessage  = "Translation failed: \(error.localizedDescription)"
            isTranslating = false
        }
    }

    // AIA: TextToSpeech1
    func speakTranslation() {
        guard !translatedText.isEmpty else { return }
        stopSpeaking()
        let bcp47     = currentLang.bcp47
        let shortCode = String(bcp47.prefix(2))
        let utterance = AVSpeechUtterance(string: translatedText)
        let voices    = AVSpeechSynthesisVoice.speechVoices()
        if let v = voices.first(where: { $0.language.hasPrefix(bcp47) })
                ?? voices.first(where: { $0.language.hasPrefix(shortCode) }) {
            utterance.voice = v
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: shortCode)
        }
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.volume = 1.0
        try? AVAudioSession.sharedInstance()
            .setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        isSpeaking = true
        synth.speak(utterance)
    }

    func stopSpeaking() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // AIA: Clear button
    func clearAll() {
        inputText      = ""
        translatedText = ""
        errorMessage   = nil
        stopSpeaking()
    }
}

// MARK: - SessionBridge
// Tiny hidden view whose only job is to hold .translationTask.
// Because it's @MainActor (all SwiftUI views are), the session callback
// is also @MainActor — same isolation as TranslatorEngine — so Swift 6
// sees no Sendable crossing when we call engine.receive(session:).

private struct SessionBridge: View {
    let engine: TranslatorEngine
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .translationTask(engine.config) { @MainActor session in
                engine.receive(session: session)
                await engine.runTranslation()
            }
    }
}

// MARK: - TranslatorView

struct TranslatorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var engine  = TranslatorEngine()
    @StateObject private var speech = SpeechManager()
    @State private var autoTranslate = false

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()

            // Hidden bridge — lives in the view tree so .translationTask fires
            SessionBridge(engine: engine).frame(width: 0, height: 0)

            ScrollView {
                VStack(spacing: 16) {

                    // ── Language picker (AIA: Spinner1) ──────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Translate to")
                            .font(.system(size: 13))
                            .foregroundStyle(appState.theme.mutedText)
                        Picker("Language", selection: $engine.selectedIndex) {
                            ForEach(engine.languages.indices, id: \.self) { i in
                                Text(engine.languages[i].name).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(appState.theme.inputBackground,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.06), radius: 4)
                        .onChange(of: engine.selectedIndex) { _, _ in
                            engine.translatedText = ""
                            engine.errorMessage   = nil
                            engine.stopSpeaking()
                        }
                    }

                    // ── Input box (AIA: TextBox1) ─────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("English text")
                                .font(.system(size: 13))
                                .foregroundStyle(appState.theme.text.opacity(0.7))
                            Spacer()
                            if !engine.inputText.isEmpty {
                                Button("Clear") { engine.clearAll() }
                                    .font(.system(size: 13))
                                    .foregroundStyle(appState.theme.accent)
                            }
                        }
                        TextEditor(text: $engine.inputText)
                            .font(.custom("CreativeThoughts-Regular", size: 16))
                            .frame(minHeight: 110)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(appState.theme.inputBackground,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(appState.theme.text)
                            .shadow(color: .black.opacity(0.05), radius: 4)
                            .onChange(of: speech.recognizedText) { _, v in
                                guard !v.isEmpty else { return }
                                engine.inputText = v
                            }
                    }

                    // ── Buttons (AIA: Get_Translation + Speak) ───────────────
                    HStack(spacing: 10) {
                        actionBtn(
                            engine.isTranslating ? "Translating…" : "Get Translation",
                            icon: engine.isTranslating ? "ellipsis" : "globe",
                            color: engine.isTranslating ? .gray : appState.theme.accent,
                            disabled: engine.isTranslating ||
                                engine.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ) { engine.triggerTranslation() }

                        actionBtn(
                            speech.isPreparing ? "Starting…" :
                                (speech.isListening ? "Stop" : "Speak"),
                            icon: speech.isListening ? "mic.slash.fill" : "mic.fill",
                            color: speech.isListening
                                ? .red
                                : Color(red: 0.45, green: 0.20, blue: 0.75),
                            disabled: speech.isPreparing
                        ) { toggleMic() }
                    }

                    // ── Output (AIA: Label1) ──────────────────────────────────
                    if !engine.translatedText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(engine.currentLang.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(appState.theme.text.opacity(0.7))
                                Spacer()
                                Button {
                                    if engine.isSpeaking { engine.stopSpeaking() }
                                    else                 { engine.speakTranslation() }
                                } label: {
                                    Image(systemName: engine.isSpeaking
                                          ? "speaker.wave.3.fill" : "speaker.wave.2")
                                        .font(.system(size: 20))
                                        .foregroundStyle(appState.theme.accent)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            Text(engine.translatedText)
                                .font(.custom("CreativeThoughts-Regular", size: 17))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(appState.theme.text)
                                .background(appState.theme.inputBackground,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // ── Error ─────────────────────────────────────────────────
                    if let err = engine.errorMessage ?? speech.errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Translator", back: .functionality)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // AIA: SpeechRecognizer1.AfterGettingText → auto-translate
        .onChange(of: speech.isListening) { oldValue, newValue in
            if oldValue && !newValue && autoTranslate {
                autoTranslate = false
                let q = engine.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty { engine.triggerTranslation() }
            }
        }
        .onAppear  { engine.setupSynthBox() }
        .onDisappear { speech.stopListening(); engine.stopSpeaking() }
    }

    // MARK: - Mic (AIA: SpeechRecognizer1)
    private func toggleMic() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speech.recognizedText = ""
            autoTranslate         = true
            speech.startListening()
        }
    }

    // MARK: - Button helper
    @ViewBuilder
    private func actionBtn(_ label: String, icon: String, color: Color,
                           disabled: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label).font(.custom("AlumniSans-Bold", size: 16))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(disabled ? Color.gray.opacity(0.5) : color,
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
    }
}

// MARK: - SynthBox
private final class SynthBox: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@MainActor () -> Void)?
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }
}
