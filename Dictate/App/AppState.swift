import SwiftUI
import AppKit

final class AppState: ObservableObject {
    // MARK: - Transient state

    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscription: String?
    @Published var errorMessage: String?
    @Published var transcriptions: [Transcription] = []
    @Published var audioLevel: Float = -160
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasAccessibilityPermission = false

    // MARK: - Settings (persisted in UserDefaults)

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var autoCopyToClipboard: Bool {
        didSet { UserDefaults.standard.set(autoCopyToClipboard, forKey: "autoCopyToClipboard") }
    }
    @Published var pauseMusicWhileRecording: Bool {
        didSet { UserDefaults.standard.set(pauseMusicWhileRecording, forKey: "pauseMusicWhileRecording") }
    }

    // MARK: - Services

    private let audioRecorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let keyboardManager = KeyboardManager()
    private let musicController = MusicController()
    private let store = TranscriptionStore()

    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var permissionTimer: Timer?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "autoCopyToClipboard": true,
            "pauseMusicWhileRecording": true
        ])

        apiKey = defaults.string(forKey: "apiKey") ?? ""
        language = defaults.string(forKey: "language") ?? ""
        autoCopyToClipboard = defaults.bool(forKey: "autoCopyToClipboard")
        pauseMusicWhileRecording = defaults.bool(forKey: "pauseMusicWhileRecording")

        transcriptions = store.load()
        setupKeyboardManager()
    }

    // MARK: - Keyboard

    func setupKeyboardManager() {
        keyboardManager.onRecordingStarted = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        keyboardManager.onRecordingStopped = { [weak self] in
            DispatchQueue.main.async { self?.stopRecording() }
        }

        hasAccessibilityPermission = keyboardManager.start()

        if !hasAccessibilityPermission {
            startPermissionPolling()
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                self.hasAccessibilityPermission = true
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.keyboardManager.stop()
                _ = self.keyboardManager.start()
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        if pauseMusicWhileRecording {
            musicController.pauseMusic()
        }

        do {
            _ = try audioRecorder.startRecording()
            isRecording = true
            startMetering()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            if pauseMusicWhileRecording {
                musicController.resumeMusic()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        stopMetering()

        guard let result = audioRecorder.stopRecording() else {
            isRecording = false
            if pauseMusicWhileRecording { musicController.resumeMusic() }
            return
        }

        isRecording = false

        // Skip very short recordings (< 0.3s)
        if result.duration < 0.3 {
            if pauseMusicWhileRecording { musicController.resumeMusic() }
            try? FileManager.default.removeItem(at: result.url)
            return
        }

        isTranscribing = true
        if pauseMusicWhileRecording { musicController.resumeMusic() }

        let currentApiKey = apiKey
        let currentLanguage = language

        Task { @MainActor in
            do {
                let text = try await transcriptionService.transcribe(
                    audioURL: result.url,
                    apiKey: currentApiKey,
                    language: currentLanguage.isEmpty ? nil : currentLanguage
                )

                lastTranscription = text

                let transcription = Transcription(text: text, duration: result.duration)
                transcriptions.insert(transcription, at: 0)
                store.save(transcriptions)

                if autoCopyToClipboard {
                    copyToClipboard(text)
                }

                isTranscribing = false
            } catch {
                errorMessage = error.localizedDescription
                isTranscribing = false
            }

            try? FileManager.default.removeItem(at: result.url)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - History management

    func deleteTranscription(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        store.save(transcriptions)
    }

    func clearHistory() {
        transcriptions.removeAll()
        store.save(transcriptions)
    }

    // MARK: - Audio metering

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioLevel = self.audioRecorder.currentLevel()
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration = self.audioRecorder.recordingDuration
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevel = -160
        recordingDuration = 0
    }
}
