import AppKit
import SwiftUI

@MainActor
final class PomodoroWindowController {
    static let shared = PomodoroWindowController()
    private var panel: NSPanel?

    private init() {}

    func start(task: TodoTask?, plannedMinutes: Int) {
        NSLog("[ES] PomodoroWindowController.start task=\(task?.title ?? "nil") minutes=\(plannedMinutes) mode=countdown")
        panel?.orderOut(nil)
        let view = PomodoroTimerView(
            task: task,
            mode: .countdown,
            plannedMinutes: plannedMinutes,
            onClose: { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        )
        showPanel(rootView: view)
    }

    /// 正计时模式启动(无 plannedMinutes,从 0 开始)
    func startCountUp(task: TodoTask?, plannedMinutes: Int = 25) {
        NSLog("[ES] PomodoroWindowController.startCountUp task=\(task?.title ?? "nil") mode=countup")
        panel?.orderOut(nil)
        let view = PomodoroTimerView(
            task: task,
            mode: .countup,
            plannedMinutes: plannedMinutes,
            onClose: { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
            }
        )
        showPanel(rootView: view)
    }

    @MainActor
    private func showPanel<V: View>(rootView: V) {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 540),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "专注"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.appearance = NSAppearance(named: .vibrantDark)
        p.contentView = NSHostingView(rootView: rootView)
        p.center()
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        self.panel = p
        NSLog("[ES] Pomodoro panel shown styleMask=\(p.styleMask.rawValue)")
    }

    func startRest(minutes: Int = 5) {
        NSLog("[ES] PomodoroWindowController.startRest minutes=\(minutes)")
        panel?.orderOut(nil)
        let view = PomodoroRestView(minutes: minutes) { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "休息"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.appearance = NSAppearance(named: .vibrantDark)
        p.contentView = NSHostingView(rootView: view)
        p.center()
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        self.panel = p
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}