import Cocoa

final class KeyboardManager {
    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive = false

    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: globalEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func handleKeyEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let type = event.type

        let isControlPressed = flags.contains(.maskControl)
        let isEscapeKey = keyCode == 53

        if type == .keyDown && isEscapeKey && isControlPressed && !isActive {
            isActive = true
            onRecordingStarted?()
        } else if type == .keyUp && isEscapeKey && isActive {
            isActive = false
            onRecordingStopped?()
        } else if type == .flagsChanged && !isControlPressed && isActive {
            isActive = false
            onRecordingStopped?()
        }
    }
}

private func globalEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        manager.reEnableTap()
        return Unmanaged.passRetained(event)
    }

    manager.handleKeyEvent(event)
    return Unmanaged.passRetained(event)
}
