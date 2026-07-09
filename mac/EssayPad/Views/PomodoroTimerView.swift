import SwiftUI
import AppKit

struct PomodoroTimerView: View {
    let task: TodoTask?
    let initialMode: TimerMode
    let initialPlannedMinutes: Int
    var onClose: () -> Void

    @State private var mode: TimerMode
    @State private var totalSeconds: Int          // 倒计时用:总秒数
    @State private var remainingSeconds: Int      // 倒计时用:剩余秒数
    @State private var elapsedSeconds: Int = 0    // 正计时用:累计秒数
    @State private var status: TimerStatus = .running
    @State private var sessionId: Int64? = nil
    @State private var ticker: Timer? = nil
    @State private var showCompletion = false
    @State private var completedActualMinutes: Int = 0
    @State private var completedWasAborted: Bool = false
    @State private var showTaskPicker = false
    @State private var currentTask: TodoTask?

    /// 任务累计时长(分钟)——从后端拉,本视图内不再单独持久化
    @State private var taskTotalMinutes: Int = 0

    enum TimerStatus { case running, paused, finished }
    enum TimerMode: String, CaseIterable, Identifiable {
        case countdown  // 倒计时
        case countup    // 正计时
        var id: String { rawValue }
        var displayName: String { self == .countdown ? "倒计时" : "正计时" }
        var icon: String { self == .countdown ? "hourglass" : "play.circle" }
    }

    init(task: TodoTask?, mode: TimerMode = .countdown, plannedMinutes: Int = 25, onClose: @escaping () -> Void) {
        self.task = task
        self.initialMode = mode
        self.initialPlannedMinutes = plannedMinutes
        self.onClose = onClose
        _mode = State(initialValue: mode)
        _totalSeconds = State(initialValue: plannedMinutes * 60)
        _remainingSeconds = State(initialValue: plannedMinutes * 60)
        _currentTask = State(initialValue: task)
        _taskTotalMinutes = State(initialValue: task?.pomodoroMinutes ?? 0)
    }

    var body: some View {
        ZStack {
            // 背景:正计时用绿色调,倒计时保持原色
            RoundedRectangle(cornerRadius: 20)
                .fill(mode == .countup
                      ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.06, green: 0.18, blue: 0.12), Color(red: 0.04, green: 0.10, blue: 0.08)], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(.ultraThinMaterial))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                modeSwitcher
                timeDisplay

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(mode == .countup ? 0.12 : 0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    Button(action: togglePause) {
                        Image(systemName: pauseIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(pauseColor, in: Circle())
                            .shadow(color: pauseColor.opacity(0.4), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    .opacity(showCompletion ? 0 : 1)
                }
                .frame(width: 180, height: 180)

                taskInfo
                switchTaskButton
                Spacer()
                bottomBar
            }
            .padding(.bottom, 8)
            .foregroundStyle(mode == .countup ? Color.white : .primary)

            if showCompletion {
                completionOverlay
            }
        }
        .frame(width: 320, height: 540)
        .onAppear { start() }
        .onDisappear { stopTicker() }
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerSheet(currentTaskID: currentTask?.id) { picked in
                switchToTask(picked)
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack {
            Label {
                Text(mode == .countup ? "正计时专注" : "倒计时专注")
                    .font(.system(size: 11, weight: .medium))
            } icon: {
                Image(systemName: mode == .countup ? "play.circle.fill" : "hourglass")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mode == .countup ? .white.opacity(0.8) : .secondary)
                    .padding(6)
                    .background(Color.gray.opacity(mode == .countup ? 0.2 : 0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// 模式切换器:倒计时 / 正计时 segmented control
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases) { m in
                Button {
                    switchMode(to: m)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: m.icon)
                            .font(.system(size: 10))
                        Text(m.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        mode == m
                            ? (mode == .countup
                               ? Color.green.opacity(0.25)
                               : Color.accentColor.opacity(0.18))
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .foregroundStyle(
                        mode == m
                            ? (mode == .countup ? Color.green : Color.accentColor)
                            : (mode == .countup ? Color.white.opacity(0.55) : Color.secondary)
                    )
                }
                .buttonStyle(.plain)
                .disabled(showCompletion)
            }
        }
        .padding(2)
        .background(
            (mode == .countup ? Color.white.opacity(0.06) : Color.gray.opacity(0.12)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 时间显示

    private var timeDisplay: some View {
        Text(formatTime(mode == .countdown ? remainingSeconds : elapsedSeconds))
            .font(.system(size: mode == .countup ? 48 : 56, weight: .semibold, design: .monospaced))
            .foregroundStyle(mode == .countup ? .white : .primary)
            .padding(.top, 4)
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.2), value: mode == .countdown ? remainingSeconds : elapsedSeconds)
    }

    // MARK: - 任务信息 + 累计

    private var taskInfo: some View {
        VStack(spacing: 3) {
            Text(currentTask?.title ?? "自由专注")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(mode == .countup ? .white : .primary)
                .lineLimit(1)
            HStack(spacing: 6) {
                // 本次
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                    Text("本次 \(formatMinutesShort(currentSessionMinutes()))")
                        .font(.system(size: 10, design: .monospaced))
                }
                if let _ = currentTask {
                    Text("·").foregroundStyle(.tertiary)
                    // 累计
                    HStack(spacing: 2) {
                        Image(systemName: "sum")
                            .font(.system(size: 9))
                        Text("累计 \(formatMinutesShort(taskTotalMinutes + currentSessionMinutes()))")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
            .foregroundStyle(mode == .countup ? .white.opacity(0.65) : .secondary)
        }
    }

    private var switchTaskButton: some View {
        Button {
            // 切任务前先 pause 一下
            if status == .running { status = .paused }
            showTaskPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 10))
                Text("切换任务")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                mode == .countup ? Color.white.opacity(0.12) : Color.gray.opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(mode == .countup ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(showCompletion)
    }

    // MARK: - 底栏

    private var bottomBar: some View {
        HStack {
            Button("提前结束") { finish(aborted: true) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(mode == .countup ? .white.opacity(0.5) : .secondary)
            Spacer()
            Button("重置") { reset() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(mode == .countup ? .white.opacity(0.5) : .secondary)
                .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var completionOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: completedWasAborted ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(completedWasAborted ? Color.orange : Color.green)
                .transition(.scale.combined(with: .opacity))
            Text(completedWasAborted ? "已结束" : (mode == .countup ? "继续加油!" : "专注完成!"))
                .font(.system(size: 20, weight: .semibold))
            Text("实际 \(formatMinutesShort(completedActualMinutes))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - 计算属性

    /// 进度环填充比例
    private var progress: Double {
        switch mode {
        case .countdown:
            guard totalSeconds > 0 else { return 0 }
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        case .countup:
            // 正计时:圆环一直缓慢填充,无明确结束
            return 0.001  // 极薄一道,只作视觉提示
        }
    }

    private var pauseIcon: String {
        switch status {
        case .running: return "pause.fill"
        case .paused: return "play.fill"
        case .finished: return "checkmark"
        }
    }

    private var pauseColor: Color {
        switch status {
        case .running: return mode == .countup ? .green : .blue
        case .paused: return .orange
        case .finished: return .green
        }
    }

    private var ringGradient: AngularGradient {
        if mode == .countup {
            // 绿色调,正计时
            return AngularGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.20, green: 0.84, blue: 0.50),
                    Color(red: 0.10, green: 0.70, blue: 0.40),
                    Color(red: 0.30, green: 0.95, blue: 0.60),
                    Color(red: 0.10, green: 0.70, blue: 0.40),
                    Color(red: 0.20, green: 0.84, blue: 0.50),
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        }
        // 倒计时:暖色(原版)
        return AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.83, blue: 0.23),
                Color(red: 1.0, green: 0.66, blue: 0.30),
                Color(red: 1.0, green: 0.42, blue: 0.42),
                Color(red: 1.0, green: 0.66, blue: 0.30),
                Color(red: 1.0, green: 0.83, blue: 0.23),
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    private func currentSessionMinutes() -> Int {
        let s = mode == .countdown ? (totalSeconds - remainingSeconds) : elapsedSeconds
        return s / 60
    }

    // MARK: - 格式化

    /// 时间格式:小时为 0 时显示 MM:SS,否则 HH:MM:SS
    private func formatTime(_ secs: Int) -> String {
        let s = max(0, secs)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d : %02d : %02d", h, m, sec)
        }
        return String(format: "%02d : %02d", m, sec)
    }

    /// 分钟格式:1h 23m / 23m / 0m
    private func formatMinutesShort(_ m: Int) -> String {
        if m <= 0 { return "0m" }
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let rest = m % 60
        if rest == 0 { return "\(h)h" }
        return "\(h)h \(rest)m"
    }

    // MARK: - 动作

    private func start() {
        NSLog("[ES] PomodoroTimerView start mode=\(mode.rawValue) planned=\(initialPlannedMinutes) task=\(currentTask?.title ?? "free")")
        if let t = currentTask {
            Task {
                do {
                    let id = try await APIClient.shared.createPomodoro(taskId: t.id, plannedMinutes: initialPlannedMinutes)
                    sessionId = id
                    NSLog("[ES] Pomodoro session created id=\(id) task=\(t.id)")
                } catch {
                    NSLog("[ES] Pomodoro create failed: \(error)")
                }
            }
        }
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard status == .running else { return }
        switch mode {
        case .countdown:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                finish(aborted: false)
            }
        case .countup:
            elapsedSeconds += 1
        }
    }

    private func togglePause() {
        guard status != .finished else { return }
        status = (status == .running) ? .paused : .running
    }

    private func reset() {
        switch mode {
        case .countdown:
            remainingSeconds = totalSeconds
        case .countup:
            elapsedSeconds = 0
        }
        status = .running
    }

    /// 切换模式(运行中也可切)
    private func switchMode(to newMode: TimerMode) {
        guard newMode != mode else { return }
        NSLog("[ES] Pomodoro switchMode \(mode.rawValue) -> \(newMode.rawValue)")
        mode = newMode
        if newMode == .countdown {
            // 切换到倒计时:把当前 elapsed 当作新的 total
            if elapsedSeconds > 60 {
                totalSeconds = elapsedSeconds
            } else {
                totalSeconds = initialPlannedMinutes * 60
            }
            remainingSeconds = totalSeconds
        }
    }

    /// 切换任务
    private func switchToTask(_ newTask: TodoTask?) {
        guard newTask?.id != currentTask?.id else { return }
        NSLog("[ES] Pomodoro switch task from \(currentTask?.title ?? "nil") to \(newTask?.title ?? "nil")")

        // 1. 收尾当前 session
        if let id = sessionId {
            let elapsedSecs = mode == .countdown ? (totalSeconds - remainingSeconds) : elapsedSeconds
            let actualMinutes = max(0, elapsedSecs / 60)
            Task {
                do {
                    _ = try await APIClient.shared.completePomodoro(
                        id: id, actualMinutes: actualMinutes, status: 1
                    )
                    NSLog("[ES] switch-task: closed old session id=\(id) actual=\(actualMinutes)min")
                } catch {
                    NSLog("[ES] switch-task: close old session failed: \(error)")
                }
            }
        }

        // 2. 启动新 session
        currentTask = newTask
        taskTotalMinutes = newTask?.pomodoroMinutes ?? 0
        elapsedSeconds = 0
        remainingSeconds = totalSeconds
        status = .running
        sessionId = nil

        if let t = newTask {
            Task {
                do {
                    let id = try await APIClient.shared.createPomodoro(taskId: t.id, plannedMinutes: initialPlannedMinutes)
                    sessionId = id
                    NSLog("[ES] switch-task: new session id=\(id) task=\(t.id)")
                } catch {
                    NSLog("[ES] switch-task: new session create failed: \(error)")
                }
            }
        }
    }

    private func finish(aborted: Bool) {
        stopTicker()
        let elapsedSecs = mode == .countdown ? (totalSeconds - remainingSeconds) : elapsedSeconds
        let actualMinutes = max(1, elapsedSecs / 60)
        completedActualMinutes = actualMinutes
        completedWasAborted = aborted
        status = .finished
        showCompletion = true
        NSLog("[ES] Pomodoro finish aborted=\(aborted) mode=\(mode.rawValue) actual=\(actualMinutes)min sessionId=\(sessionId ?? 0)")
        if let id = sessionId {
            Task {
                do {
                    _ = try await APIClient.shared.completePomodoro(
                        id: id, actualMinutes: actualMinutes, status: aborted ? 2 : 1
                    )
                    NSLog("[ES] Pomodoro complete api ok id=\(id)")
                } catch {
                    NSLog("[ES] Pomodoro complete api failed: \(error)")
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onClose()
        }
    }
}
