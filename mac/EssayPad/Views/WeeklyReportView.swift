import SwiftUI
import AppKit

struct WeeklyReportView: View {
    var onClose: () -> Void
    @State private var report: APIClient.WeeklyReport?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedPreset: WeeklyPreset = .week

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        LinearGradient(colors: [.purple, .indigo],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 周报")
                        .font(.system(size: 22, weight: .bold))
                    Text(rangeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await generate(force: true) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("重新生成")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(loading)
                .help("忽略缓存,重新调用 AI 生成")
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: 6) {
                        if loading {
                            ProgressView()
                                .scaleEffect(0.55)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(loading ? "生成中…" : "生成周报")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .disabled(loading)
                .keyboardShortcut(.return, modifiers: .command)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .padding(7)
                        .background(Color(nsColor: .controlBackgroundColor),
                                    in: Circle())
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            HStack(spacing: 6) {
                ForEach([WeeklyPreset.today, .yesterday, .week], id: \.self) { p in
                    Button {
                        if selectedPreset != p && !loading {
                            selectedPreset = p
                            Task { await generate() }
                        }
                    } label: {
                        Text(presetLabel(p))
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(presetBackground(p),
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(selectedPreset == p ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(loading)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Divider()

            if let err = error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.callout)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            ScrollView {
                VStack(spacing: 14) {
                    if loading {
                        VStack(spacing: 14) {
                            Spacer().frame(height: 40)
                            ProgressView()
                                .scaleEffect(1.6)
                            Text("正在分析你的随笔…")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else if let r = report {
                        ReportCard(title: "总结", icon: "text.alignleft",
                                   color: .blue, items: nil,
                                   summary: r.summary)
                        ReportCard(title: "要点", icon: "star.fill",
                                   color: .green,
                                   items: r.highlights,
                                   summary: nil)
                        ReportCard(title: "行动", icon: "arrow.right.circle.fill",
                                   color: .orange,
                                   items: r.actionItems,
                                   summary: nil)
                        HStack(spacing: 6) {
                            if r.fromCache ?? false {
                                Image(systemName: "tray.full")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("缓存于 \(formatTime(r.createdAt))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("本次基于 \(r.noteCount) 条笔记全新生成 · \(formatTime(r.createdAt))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    } else {
                        EmptyReportView()
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func generate(force: Bool = false) async {
        loading = true
        defer { loading = false }
        do {
            report = try await APIClient.shared.generateWeekly(preset: selectedPreset, force: force)
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    private func formatTime(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func presetLabel(_ p: WeeklyPreset) -> String {
        switch p {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .week: return "本周"
        }
    }

    private func presetBackground(_ p: WeeklyPreset) -> Color {
        if selectedPreset == p {
            return .accentColor
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var rangeDescription: String {
        switch selectedPreset {
        case .today: return "今天 00:00 ~ 现在"
        case .yesterday: return "昨天 00:00 ~ 今天 00:00"
        case .week: return "今天往前 6 天 ~ 今天 24:00(共 7 天)"
        }
    }
}

private struct ReportCard: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]?
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(color, in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            Group {
                if let summary {
                    Text(summary)
                        .font(.system(size: 14))
                        .lineSpacing(3)
                }
                if let items {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(color)
                                .font(.system(size: 14, weight: .bold))
                            Text(item)
                                .font(.system(size: 14))
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(color)
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .top)
            , alignment: .top
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}

private struct EmptyReportView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有生成过周报")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击上方时间范围和「生成周报」,AI 会按选定时间窗口总结随笔内容")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(40)
    }
}
