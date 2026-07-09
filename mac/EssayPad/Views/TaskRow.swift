import SwiftUI

struct TaskRow: View {
    let task: TodoTask
    var onTap: () -> Void = {}
    let onProgress: (Int) -> Void
    let onComplete: () -> Void
    let onMoveToToday: () -> Void
    let onDelete: () -> Void
    let onChangePriority: (Int) -> Void
    let onShowConfetti: () -> Void
    var onStartPomodoro: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: task.priority == 0 ? 2 : (task.priority == 1 ? 3 : 4))
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.isDone ? "✓" : "●")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(task.isDone ? Color.green : priorityColor)
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                        .lineLimit(2)
                    Spacer()
                }
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    ProgressBar(progress: task.progress, color: progressColor)
                        .frame(height: 6)
                    Text("\(task.progress)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(progressColor)
                        .frame(width: 36, alignment: .trailing)
                }
                if !task.isDone && task.pomodoroCount > 0 {
                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            Text("🍅")
                                .font(.system(size: 10))
                            Text("\(task.pomodoroCount) 次")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                        if task.pomodoroMinutes > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(formatMinutes(task.pomodoroMinutes))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                if task.isDone, task.completedAt > 0 {
                    Text("完成于 \(formatShortTime(task.completedAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 4) {
                if !task.isDone {
                    Button(action: onStartPomodoro) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                            .frame(width: 20, height: 20)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("开始专注(默认 25 分钟)")

                    ProgressRingButton(progress: task.progress, color: progressColor) {
                        let next = min(task.progress + 25, 100)
                        onProgress(next)
                    }
                    .help("进度 +25%(当前 \(task.progress)%)")

                    Button {
                        onShowConfetti()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onComplete()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.green.opacity(0.85))
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("标记完成")
                }
                Menu {
                    if task.isOverdue {
                        Button("移到今天") { onMoveToToday() }
                    }
                    if task.priority < 2 {
                        Button(task.priority == 0 ? "提升为重要" : "提升为紧急") {
                            onChangePriority(task.priority + 1)
                        }
                    }
                    if task.priority > 0 {
                        Button("降低优先级") {
                            onChangePriority(task.priority - 1)
                        }
                    }
                    Divider()
                    Button("删除", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onTap()
        }
    }

    private var rowBackground: Color {
        if task.isDone { return Color(nsColor: .controlBackgroundColor).opacity(0.5) }
        switch task.priority {
        case 2: return Color.red.opacity(0.05)
        case 1: return Color.orange.opacity(0.05)
        default: return Color(nsColor: .controlBackgroundColor)
        }
    }

    var priorityColor: Color {
        switch task.priority {
        case 2: return Color.red
        case 1: return Color.orange
        default: return Color.gray.opacity(0.3)
        }
    }
    var progressColor: Color {
        switch task.progress {
        case 100: return Color.green
        case 75: return Color.blue
        case 50: return Color.orange
        case 25: return Color.red
        default: return Color.gray.opacity(0.4)
        }
    }

    private func formatShortTime(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInYesterday(date) {
            f.dateFormat = "昨天 HH:mm"
        } else {
            f.dateFormat = "MM-dd HH:mm"
        }
        return f.string(from: date)
    }

    private func formatMinutes(_ m: Int) -> String {
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h\(rem)m"
    }
}

struct ProgressBar: View {
    let progress: Int
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.2))
                RoundedRectangle(cornerRadius: 3).fill(color)
                    .frame(width: geo.size.width * CGFloat(progress) / 100)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
            }
        }
    }
}

struct ProgressRingButton: View {
    let progress: Int
    let color: Color
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(color.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(progress) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
                if progress == 0 {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(color.opacity(0.7))
                } else {
                    Text("\(progress / 25)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
            .scaleEffect(hovering ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("点击 +25%(当前 \(progress)%)")
    }
}