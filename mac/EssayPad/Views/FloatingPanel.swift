import AppKit
import SwiftUI

final class FloatingPanel<Content: View>: NSPanel {
    init(contentRect: NSRect, content: () -> Content) {
        super.init(contentRect: contentRect, styleMask: [.titled, .resizable, .closable, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.contentView = NSHostingView(rootView: content())
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class QuickCaptureWindowController {
    static let shared = QuickCaptureWindowController()
    private var panel: FloatingPanel<AnyView>?

    func toggle() {
        if let p = panel, p.isVisible {
            p.orderOut(nil)
            return
        }
        open(note: nil)
    }

    func openForEditing(_ note: Note) {
        if let p = panel, p.isVisible {
            p.orderOut(nil)
        }
        open(note: note)
    }

    private func open(note: Note?) {
        let view = QuickCaptureView(
            editingNote: note,
            onClose: { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        let p = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                              content: { AnyView(view) })
        p.center()
        p.makeKeyAndOrderFront(nil)
        if let cv = p.contentView {
            DispatchQueue.main.async {
                p.makeFirstResponder(cv)
            }
        }
        self.panel = p
    }
}
