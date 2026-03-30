import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("API Configuration") {
                SecureField("OpenAI API Key", text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Language code (optional, e.g. en, fr, de)", text: $appState.language)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Behavior") {
                Toggle("Auto-copy transcription to clipboard", isOn: $appState.autoCopyToClipboard)
                Toggle("Pause music while recording", isOn: $appState.pauseMusicWhileRecording)
            }

            Section("Shortcut") {
                HStack {
                    Text("Hold to record")
                    Spacer()
                    Text("\u{2303} Escape")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if appState.hasAccessibilityPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Button("Grant Access") {
                            appState.requestAccessibilityPermission()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Dictate")
                    Spacer()
                    Text("v1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
    }
}
