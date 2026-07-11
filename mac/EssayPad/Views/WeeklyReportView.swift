import SwiftUI

struct WeeklyReportView: View {
    var onClose: () -> Void
    @State private var report: APIClient.WeeklyReport?
    @State private var messages: [APIClient.WeeklyReflectionMessage] = []
    @State private var input = ""
    @State private var loading = false
    @State private var sending = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label("和 AI 聊聊这一周", systemImage: "message").font(.headline); Spacer(); Text("对话会保存在本次复盘中").font(.caption).foregroundStyle(.secondary) }
            ForEach(messages) { message in HStack { if message.isAssistant { Text(message.content).bubble(.assistant); Spacer(minLength: 48) } else { Spacer(minLength: 48); Text(message.content).bubble(.user) } } }
            HStack(spacing: 7) { Button("回答一下") { input = "我想聊聊这周最重要的一件事。" }.buttonStyle(.bordered); Button("换个问题") { input = "换个问题" }.buttonStyle(.bordered) }
            HStack { TextField("继续聊聊这一周…", text: $input).textFieldStyle(.roundedBorder).onSubmit { Task { await send() } }; Button("发送") { Task { await send() } }.buttonStyle(.borderedProminent).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending) }
        }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View { VStack(spacing: 12) { Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.tertiary); Text("准备好和这一周聊聊了吗？").font(.headline); Button("生成本周复盘") { Task { await generate() } }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, minHeight: 300) }
    private func generate(force: Bool = false) async { loading = true; defer { loading = false }; do { let value = try await APIClient.shared.generateWeekly(preset: selectedPreset, force: force); report = value; messages = try await APIClient.shared.listWeeklyMessages(reportID: value.id); error = nil } catch let requestError { error = (requestError as? APIError)?.errorDescription ?? requestError.localizedDescription } }
    private func send() async { guard let report else { return }; let text = input.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; sending = true; defer { sending = false }; do { let pair = try await APIClient.shared.sendWeeklyMessage(reportID: report.id, content: text); messages += [pair.0, pair.1]; input = "" } catch let requestError { error = (requestError as? APIError)?.errorDescription ?? requestError.localizedDescription } }
    private var rangeDescription: String { selectedPreset == .week ? "最近 7 天的本地记录" : selectedPreset == .today ? "今天的本地记录" : "昨天的本地记录" }
}

private enum ReflectionBubble { case assistant, user }
private extension View { func bubble(_ kind: ReflectionBubble) -> some View { padding(10).font(.system(size: 13)).foregroundStyle(kind == .assistant ? Color.primary : Color.white).background(kind == .assistant ? Color.accentColor.opacity(0.12) : Color.accentColor, in: RoundedRectangle(cornerRadius: 8)) } }
