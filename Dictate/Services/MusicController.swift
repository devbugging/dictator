import CoreAudio
import Foundation

final class MusicController {
    private var wasMuted = false

    func muteSystemAudio() {
        // Check current mute state so we can restore it
        wasMuted = isSystemMuted()
        if !wasMuted {
            setSystemMute(true)
        }
    }

    func restoreSystemAudio() {
        // Only unmute if we were the ones who muted it
        if !wasMuted {
            setSystemMute(false)
        }
    }

    // MARK: - CoreAudio helpers

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func isSystemMuted() -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        return muted != 0
    }

    private func setSystemMute(_ mute: Bool) {
        guard let deviceID = defaultOutputDeviceID() else { return }
        var value: UInt32 = mute ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
    }
}
