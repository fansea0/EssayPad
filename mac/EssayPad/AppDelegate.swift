import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkey = GlobalHotkey.register(
            keyCode: GlobalHotkey.optionSpace.keyCode,
            modifiers: GlobalHotkey.optionSpace.modifiers
        ) {
            Task { @MainActor in
                QuickCaptureWindowController.shared.toggle()
            }
        }
    }
}
