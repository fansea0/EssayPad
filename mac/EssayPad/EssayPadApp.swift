import SwiftUI

extension Notification.Name {
    static let toggleShortcuts = Notification.Name("EssayPad.toggleShortcuts")
    static let startPomodoroFree = Notification.Name("EssayPad.startPomodoroFree")
    static let startPomodoroRest = Notification.Name("EssayPad.startPomodoroRest")
    static let startPomodoroCountUp = Notification.Name("EssayPad.startPomodoroCountUp")
}

@main
struct EssayPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = NoteStore.shared
    @State private var aiConfig = AIConfigurationStore.shared
    @State private var serverRunning = false
    @State private var settingsWindowOpen = false

    var body: some Scene {
        WindowGroup("EssayPad") {
            Group {
                if serverRunning {
                    ContentView().environment(store)
                } else {
                    ServerNotRunningView { await checkServer() }
                }
            }
            .task { await checkServer() }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                // 不在这里绑定 ⌘, —— Settings Scene 负责
                Button("快捷键") {
                    NotificationCenter.default.post(name: .toggleShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }
            CommandMenu("专注") {
                Button("开始专注(倒计时)") {
                    NotificationCenter.default.post(name: .startPomodoroFree, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("开始正计时") {
                    NotificationCenter.default.post(name: .startPomodoroCountUp, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                Button("开始 5 分钟休息") {
                    NotificationCenter.default.post(name: .startPomodoroRest, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        // 标准 macOS 设置窗口:自动生成「设置…」菜单项 + ⌘, 快捷键
        Settings {
            SettingsView()
        }
    }

    private func checkServer() async {
        serverRunning = await LocalServerManager.isRunning()
        if serverRunning {
            await aiConfig.loadIfNeeded()
        }
    }
}

private struct ServerNotRunningView: View {
    var onRetry: () async -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle)
            Text("EssayPad 后端未启动").font(.headline)
            Text("请先运行 `cd server && make run`").foregroundColor(.secondary)
            Button("重试") {
                Task { await onRetry() }
            }
        }
        .padding(40)
    }
}
