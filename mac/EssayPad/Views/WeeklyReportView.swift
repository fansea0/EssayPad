import SwiftUI

struct WeeklyReportView: View {
    var onClose: () -> Void
    @State private var report: APIClient.WeeklyReport?
    @State private var messages: [APIClient.WeeklyReflectionMessage] = []
    @State private var input = ""
    @State private var loading = false
    @State private var sending = false
    @State private var streamingText = ""
    @State private var error: String?
    @State private var selectedPreset: WeeklyPreset = .week

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error { Text(error).font(.callout).foregroundStyle(.red).padding(10) }
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if loading { ProgressView("正在阅读这周的笔记、日记和任务…").frame(maxWidth: .infinity, minHeight: 300) }
                    else if let reflection = report?.reflection { reflectionContent(reflection) }
                    else { emptyState }
                }.padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(.white).frame(width: 38, height: 38).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) { Text("AI 周复盘").font(.title2.bold()); Text(rangeDescription).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Picker("范围", selection: $selectedPreset) { Text("今天").tag(WeeklyPreset.today); Text("昨天").tag(WeeklyPreset.yesterday); Text("本周").tag(WeeklyPreset.week) }
                .pickerStyle(.segmented).frame(width: 190).disabled(loading).onChange(of: selectedPreset) { _, _ in Task { await generate() } }
            Button { Task { await generate(force: true) } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.bordered).help("重新生成")
            Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.bordered).help("关闭")
        }.padding(.horizontal, 28).padding(.vertical, 16)
    }

    @ViewBuilder private func reflectionContent(_ r: APIClient.WeeklyReflection) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text("给这一周的你").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor); Text(r.oneLiner).font(.title2.bold()); Text(r.greeting).foregroundStyle(.secondary).lineSpacing(3) }
            .padding(22).background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        reflectionSection("本周故事", "book.closed", body: r.story)
        reflectionList("我观察到的你", "eye", items: r.observations, color: .blue)
        reflectionList("本周成长", "arrow.up.right", items: r.growth, color: .green)
        reflectionList("下周建议", "target", items: r.suggestions, color: .orange)
        chatArea
    }

    private func reflectionSection(_ title: String, _ icon: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { sectionTitle(title, icon, .blue); Text(body).font(.system(size: 14)).lineSpacing(5).foregroundStyle(.primary) }
    }
    private func reflectionList(_ title: String, _ icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) { sectionTitle(title, icon, color); ForEach(items, id: \.self) { item in HStack(alignment: .top, spacing: 9) { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(color).padding(.top, 3); Text(item).font(.system(size: 14)).lineSpacing(3) } } }
    }
    private func sectionTitle(_ title: String, _ icon: String, _ color: Color) -> some View { Label(title, systemImage: icon).font(.headline).foregroundStyle(color) }

    private var chatArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("和 AI 聊聊这一周", systemImage: "message").font(.headline); Spacer(); Button { Task { await clearMessages() } } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("清空聊天记录") }
            ForEach(messages) { message in HStack { if message.isAssistant { ReflectionMessageText(content: message.content).bubble(.assistant); Spacer(minLength: 48) } else { Spacer(minLength: 48); Text(message.content).bubble(.user) } } }
            if !streamingText.isEmpty { HStack { ReflectionMessageText(content: streamingText + "▍").bubble(.assistant); Spacer(minLength: 48) } }
            let questions = report?.reflection?.suggestedQuestions ?? []
            if !questions.isEmpty { FlowLayout(spacing: 7) { ForEach(questions, id: \.self) { question in Button(question) { input = question }.buttonStyle(.bordered) } } }
            HStack(spacing: 10) { TextField("写下你的想法…", text: $input).textFieldStyle(.plain).font(.system(size: 15)).padding(.horizontal, 14).frame(height: 42).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18))); Button { Task { await send() } } label: { Image(systemName: "arrow.up") .font(.system(size: 14, weight: .bold)).frame(width: 42, height: 42).background(Color.accentColor, in: Circle()).foregroundStyle(.white) }.buttonStyle(.plain).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending) }
        }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View { VStack(spacing: 12) { Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.tertiary); Text("准备好和这一周聊聊了吗？").font(.headline); Button("生成本周复盘") { Task { await generate() } }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, minHeight: 300) }
    private func generate(force: Bool = false) async { loading = true; defer { loading = false }; do { let value = try await APIClient.shared.generateWeekly(preset: selectedPreset, force: force); report = value; messages = try await APIClient.shared.listWeeklyMessages(reportID: value.id); error = nil } catch let requestError { error = (requestError as? APIError)?.errorDescription ?? requestError.localizedDescription } }
    private func send() async { guard let report else { return }; let text = input.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; sending = true; defer { sending = false }; do { let pair = try await APIClient.shared.sendWeeklyMessage(reportID: report.id, content: text); messages.append(pair.0); input = ""; streamingText = ""; for character in pair.1.content { streamingText.append(character); try? await Task.sleep(nanoseconds: 18_000_000) }; messages.append(pair.1); streamingText = "" } catch let requestError { error = (requestError as? APIError)?.errorDescription ?? requestError.localizedDescription } }
    private func clearMessages() async { guard let report else { return }; do { try await APIClient.shared.deleteWeeklyMessages(reportID: report.id); messages = [] } catch let requestError { error = (requestError as? APIError)?.errorDescription ?? requestError.localizedDescription } }
    private var rangeDescription: String { selectedPreset == .week ? "最近 7 天的本地记录" : selectedPreset == .today ? "今天的本地记录" : "昨天的本地记录" }
}

private enum ReflectionBubble { case assistant, user }
private struct ReflectionMessageText: View { let content: String; var body: some View { Text((try? AttributedString(markdown: content)) ?? AttributedString(content)).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled) } }
private extension View { func bubble(_ kind: ReflectionBubble) -> some View { padding(14).foregroundStyle(kind == .assistant ? Color.primary : Color.white).background(kind == .assistant ? Color.accentColor.opacity(0.10) : Color.accentColor, in: RoundedRectangle(cornerRadius: 9)) } }
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += row + spacing
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += row + spacing
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
