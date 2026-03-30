import Foundation

final class MusicController {
    private var wasMusicPlaying = false
    private var wasSpotifyPlaying = false

    func pauseMusic() {
        wasMusicPlaying = runAppleScript("""
            tell application "Music"
                if it is running then
                    if player state is playing then
                        pause
                        return "true"
                    end if
                end if
            end tell
            return "false"
        """) == "true"

        wasSpotifyPlaying = runAppleScript("""
            tell application "Spotify"
                if it is running then
                    if player state is playing then
                        pause
                        return "true"
                    end if
                end if
            end tell
            return "false"
        """) == "true"
    }

    func resumeMusic() {
        if wasMusicPlaying {
            _ = runAppleScript("""
                tell application "Music"
                    play
                end tell
            """)
            wasMusicPlaying = false
        }
        if wasSpotifyPlaying {
            _ = runAppleScript("""
                tell application "Spotify"
                    play
                end tell
            """)
            wasSpotifyPlaying = false
        }
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        return result?.stringValue
    }
}
