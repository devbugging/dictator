import AVFoundation
import Foundation

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    var recordingDuration: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("dictate_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        startTime = Date()

        return url
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = recorder else { return nil }
        let duration = recordingDuration
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        self.startTime = nil
        return (url, duration)
    }

    func currentLevel() -> Float {
        recorder?.updateMeters()
        return recorder?.averagePower(forChannel: 0) ?? -160
    }
}
