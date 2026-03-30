import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var copiedId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            statusSection
            Divider()
            historySection
            Divider()
            footerSection
        }
        .frame(width: 340)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 8) {
            if !appState.hasAccessibilityPermission {
                permissionPrompt
            } else if appState.apiKey.isEmpty {
                setupPrompt
            } else if appState.isRecording {
                recordingStatus
            } else if appState.isTranscribing {
                transcribingStatus
            } else {
                readyStatus
            }

            if let error = appState.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        appState.errorMessage = nil
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(16)
    }

    private var permissionPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Accessibility Permission Required")
                .font(.headline)
            Text("Grant access in System Settings to enable the keyboard shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open System Settings") {
                appState.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var setupPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("API Key Required")
                .font(.headline)
            Text("Add your OpenAI API key in Settings to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsLink {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var recordingStatus: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())
                Text("Recording")
                    .font(.headline)
                Spacer()
                Text(formatDuration(appState.recordingDuration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            AudioLevelBar(level: appState.audioLevel)

            Text("Release to transcribe")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transcribingStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Transcribing...")
                .font(.headline)
            Spacer()
        }
    }

    private var readyStatus: some View {
        HStack {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("Ready")
                .font(.headline)
            Spacer()
            Text("Hold \u{2303} Esc")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if appState.transcriptions.isEmpty {
            VStack(spacing: 8) {
                Text("No transcriptions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Hold \u{2303} Esc to start dictating")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.transcriptions) { item in
                        TranscriptionRow(
                            item: item,
                            isCopied: copiedId == item.id,
                            onCopy: { copyItem(item) },
                            onDelete: { appState.deleteTranscription(item) }
                        )
                        if item.id != appState.transcriptions.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: 350)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if !appState.transcriptions.isEmpty {
                Button("Clear All") {
                    appState.clearHistory()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            SettingsLink {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func copyItem(_ item: Transcription) {
        appState.copyToClipboard(item.text)
        copiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == item.id { copiedId = nil }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Level Bar

struct AudioLevelBar: View {
    let level: Float

    private var normalizedLevel: CGFloat {
        let minDb: Float = -50
        let clamped = max(minDb, min(0, level))
        return CGFloat((clamped - minDb) / (0 - minDb))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.7), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * normalizedLevel)
                    .animation(.linear(duration: 0.05), value: normalizedLevel)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
