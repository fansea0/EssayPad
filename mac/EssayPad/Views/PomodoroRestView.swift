import SwiftUI

struct PomodoroRestView: View {
    let minutes: Int
    var onClose: () -> Void

    @State private var totalSeconds: Int
    @State private var remainingSeconds: Int
    @State private var status: PomodoroTimerView.TimerStatus = .running
    @State private var ticker: Timer? = nil

    init(minutes: Int = 5, onClose: @escaping () -> Void) {
        self.minutes = minutes
        self.onClose = onClose
        _totalSeconds = State(initialValue: minutes * 60)
        _remainingSeconds = State(initialValue: minutes * 60)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("休息 · \(minutes) 分钟")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color.gray.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 56, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green, Color.green.opacity(0.5)]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    Button(action: togglePause) {
                        Image(systemName: status == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.green, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 180, height: 180)

                VStack(spacing: 4) {
                    Text("休息中")
                        .font(.system(size: 16, weight: .medium))
                    Text("完成后自动通知你")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Button("提前结束") { finish() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("跳过休息") { finish() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 320, height: 480)
        .onAppear { startTicker() }
        .onDisappear { stopTicker() }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    private func formatTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d : %02d", m, s)
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
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            finish()
        }
    }
    private func togglePause() {
        if status == .running { status = .paused } else { status = .running }
    }
    private func finish() {
        stopTicker()
        onClose()
    }
}