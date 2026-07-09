import AppKit
import Carbon.HIToolbox

final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private static var nextID: UInt32 = 1

    static func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> GlobalHotkey {
        let hk = GlobalHotkey()
        hk.handler = handler
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let hk = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hk.handler?() }
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(hk).toOpaque()), nil)
        let hotKeyID = EventHotKeyID(signature: OSType(0x45535041), id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hk.hotKeyRef = ref
        return hk
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit { unregister() }
}

extension GlobalHotkey {
    static let optionSpace: (keyCode: UInt32, modifiers: UInt32) = (49, UInt32(optionKey))
}
