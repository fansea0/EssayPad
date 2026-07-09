import SwiftUI

struct PomodoroSetupView: View {
    let task: TodoTask?
    let onStart: (Int) -> Void
    let onCancel: () -> Void

    @State private var minutes: Int = 25
    @State private var customValue: Int = 25
    @State private var showingCustom = false

    private let presets = [15, 25, 45]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(.orange)
                    Text("专注")
                        .font(.headline)
                }
                Spacer()
                if let t = task {
                    Text(t.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.gray.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            VStack(spacing: 4) {
                Text(formatTime(minutes * 60))
                    .font(.system(size: 56, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(showingCustom ? "自定义" : "默认 \(minutes) 分钟")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { p in
                    Button {
                        minutes = p
                        showingCustom = false
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(p)")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text("分")
                                .font(.system(size: 10))
                        }
                        .frame(width: 64, height: 50)
                        .background(
                            (!showingCustom && minutes == p) ? Color.blue : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .foregroundStyle((!showingCustom && minutes == p) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showingCustom = true
                    customValue = minutes
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                        Text("自定")
                            .font(.system(size: 10))
                    }
                    .frame(width: 64, height: 50)
                    .background(
                        showingCustom ? Color.blue : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .foregroundStyle(showingCustom ? .white : .primary)
                }
                .buttonStyle(.plain)
            }

            if showingCustom {
                HStack(spacing: 8) {
                    Button {
                        if customValue > 1 { customValue -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    Text("\(customValue) 分钟")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .frame(width: 80)
                    Button {
                        if customValue < 120 { customValue += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
                .onChange(of: customValue) { _, v in minutes = v }
            }

            if let t = task {
                VStack(alignment: .leading, spacing: 4) {
                    Text("—— 任务 ——")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 6) {
                        Text(priorityLabel(t.priority))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(priorityTint(t.priority).opacity(0.15), in: Capsule())
                            .foregroundStyle(priorityTint(t.priority))
                        Text("进度 \(t.progress)%")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if t.pomodoroCount > 0 {
                        Text("累计 \(t.pomodoroCount) 个番茄 · \(t.pomodoroMinutes) 分钟")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                onStart(minutes)
            } label: {
                Text("开 始 专 注")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(20)
        .frame(width: 360)
    }

    private func formatTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d : %02d", m, s)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 2: return "🔥 紧急"
        case 1: return "⭐ 重要"
        default: return "普通"
        }
    }
    private func priorityTint(_ p: Int) -> Color {
        switch p {
        case 2: return .red
        case 1: return .orange
        default: return .gray
        }
    }
}