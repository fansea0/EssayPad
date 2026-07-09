import SwiftUI

private enum DiarySaveState: Equatable {
    case idle
    case saving
    case saved
    case error(String)
}

struct DiarySidebarView: View {
    @Bindable var store: DiaryStore
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            modeTabs
            diaryList
        }
        .task {
            await store.load()
            await store.openToday()
        }
        .onChange(of: store.listMode) { _, _ in
            Task { await store.load() }
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("搜索日记…", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await store.load() } }
                    .onChange(of: store.searchText) { _, _ in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            guard !Task.isCancelled else { return }
                            await store.load()
                        }
                    }

                Button {
                    Task { await store.openToday() }
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("打开今天")
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(DiaryListMode.allCases) { mode in
                Button {
                    store.listMode = mode
                } label: {
                    Text(mode.name)
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            store.listMode == mode ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(store.listMode == mode ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var diaryList: some View {
        if store.loading && store.entries.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.entries.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "book.closed")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.secondary)
                Text(store.searchText.isEmpty ? "还没有日记" : "没有匹配的日记")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("打开今天开始写")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(20)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.entries) { entry in
                        DiaryRow(
                            entry: entry,
                            isSelected: store.selectedEntry?.id == entry.id
                                || (store.selectedEntry == nil && store.selectedDate == entry.diaryDate)
                        ) {
                            Task { await store.openDate(entry.diaryDate) }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct DiaryRow: View {
    let entry: DiaryEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(dayText(entry.diaryDate))
                        .font(.system(size: 18, weight: .bold))
                    Text(monthText(entry.diaryDate))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(width: 40, height: 42)
                .background(
                    (isSelected ? Color.accentColor : Color.accentColor.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 7)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? "无标题日记" : entry.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(entry.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(entry.moodName) · \(entry.statusName) · \(entry.activityName)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayText(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func monthText(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM月"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

struct DiaryEditorView: View {
    @Bindable var store: DiaryStore
    @State private var title: String
    @State private var content: String
    @State private var mood: DiaryMood
    @State private var status: DiaryStatus
    @State private var activity: DiaryActivity
    @State private var savedEntry: DiaryEntry?
    @State private var saveState: DiarySaveState = .idle
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var hoveringToolbar = false

    init(store: DiaryStore) {
        self.store = store
        let entry = store.selectedEntry
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _mood = State(initialValue: DiaryMood(rawValue: entry?.mood ?? DiaryMood.calm.rawValue) ?? .calm)
        _status = State(initialValue: DiaryStatus(rawValue: entry?.status ?? DiaryStatus.good.rawValue) ?? .good)
        _activity = State(initialValue: DiaryActivity(rawValue: entry?.activity ?? DiaryActivity.work.rawValue) ?? .work)
        _savedEntry = State(initialValue: entry)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
                .padding(.horizontal, 32)
            dateStrip
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
            titleField
            metaArea
                .padding(.horizontal, 32)
                .padding(.bottom, 10)
            Divider()
                .padding(.horizontal, 32)
            editorArea
            Spacer(minLength: 0)
            Divider()
                .padding(.horizontal, 32)
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: title) { _, _ in scheduleAutoSave() }
        .onChange(of: content) { _, _ in scheduleAutoSave() }
        .onChange(of: mood) { _, _ in scheduleAutoSave() }
        .onChange(of: status) { _, _ in scheduleAutoSave() }
        .onChange(of: activity) { _, _ in scheduleAutoSave() }
        .onDisappear {
            autoSaveTask?.cancel()
            autoSaveTask = nil
        }
        .background(
            Button("") {
                autoSaveTask?.cancel()
                autoSaveTask = Task { await autoSave() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color.accentColor)
                Text("日记")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(formatFullDate(store.selectedDate))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if hoveringToolbar {
                Button {
                    ClipboardHelper.copy(toMarkdownString())
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制 Markdown")

                Menu {
                    if savedEntry != nil {
                        Button("删除", role: .destructive) {
                            Task { await store.deleteSelected() }
                        }
                    }
                    Button("复制纯文本") {
                        ClipboardHelper.copy(toPlainTextString())
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary.opacity(0.001))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onHover { hoveringToolbar = $0 }
    }

    private var dateStrip: some View {
        HStack(spacing: 6) {
            ForEach(lastSevenDates(), id: \.self) { date in
                Button {
                    Task { await store.openDate(date) }
                } label: {
                    VStack(spacing: 3) {
                        Text(weekdayText(date))
                            .font(.system(size: 10, weight: .medium))
                        Text(dayText(date))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(width: 44, height: 42)
                    .background(
                        store.selectedDate == date ? Color.accentColor : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .foregroundStyle(store.selectedDate == date ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var titleField: some View {
        TextField("今天发生了什么？", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 32)
            .padding(.bottom, 10)
    }

    private var metaArea: some View {
        VStack(spacing: 8) {
            DiaryOptionGroup(
                title: "心情",
                options: DiaryMood.allCases.filter { $0 != .none }.map { DiaryOption(id: $0.rawValue, icon: $0.icon, title: $0.name) },
                selected: mood.rawValue,
                onSelect: { mood = DiaryMood(rawValue: $0) ?? .calm }
            )
            DiaryOptionGroup(
                title: "状态",
                options: DiaryStatus.allCases.filter { $0 != .none }.map { DiaryOption(id: $0.rawValue, icon: nil, title: $0.name) },
                selected: status.rawValue,
                onSelect: { status = DiaryStatus(rawValue: $0) ?? .good }
            )
            DiaryOptionGroup(
                title: "活动",
                options: DiaryActivity.allCases.filter { $0 != .none }.map { DiaryOption(id: $0.rawValue, icon: $0.icon, title: $0.name) },
                selected: activity.rawValue,
                onSelect: { activity = DiaryActivity(rawValue: $0) ?? .work }
            )
        }
    }

    private var editorArea: some View {
        MarkdownStyledEditor(
            text: content,
            onTextChange: { newValue in
                if content != newValue {
                    content = newValue
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("\(wordCount) 字")
                .foregroundStyle(.secondary)
            saveStatusView
            Spacer()
            Text("⌘B/I/K/U  样式  ⌘⇧K 代码  ⌘⇧H 标题")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    @ViewBuilder
    private var saveStatusView: some View {
        switch saveState {
        case .idle:
            if let saved = savedEntry {
                Text("· \(relativeTime(saved.updatedAt))")
                    .foregroundStyle(.secondary)
            }
        case .saving:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("保存中")
                    .foregroundStyle(.secondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                Text("已保存")
                    .foregroundStyle(.secondary)
            }
            .task(id: saveState) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if saveState == .saved { saveState = .idle }
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .foregroundStyle(.red)
            }
            .help(msg)
        }
    }

    private var wordCount: Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let cjk = content.reduce(0) { acc, char in
            let s = String(char)
            return acc + (s.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil ? 1 : 0)
        }
        let nonCjk = content
            .replacingOccurrences(of: "[\\u4e00-\\u9fa5]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .count
        return cjk + nonCjk
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await autoSave()
        }
    }

    private func autoSave() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !cleanContent.isEmpty || mood != .none || status != .none || activity != .none else {
            saveState = .idle
            return
        }

        if let saved = savedEntry {
            guard saved.title != title || saved.content != content ||
                    saved.mood != mood.rawValue || saved.status != status.rawValue ||
                    saved.activity != activity.rawValue else {
                saveState = .idle
                return
            }
            saveState = .saving
            if let updated = await store.update(saved, title: title, content: content,
                                                mood: mood.rawValue, status: status.rawValue,
                                                activity: activity.rawValue) {
                savedEntry = updated
                saveState = .saved
            } else {
                saveState = .error(store.error ?? "保存失败")
            }
            return
        }

        saveState = .saving
        if let created = await store.save(date: store.selectedDate, title: title, content: content,
                                          mood: mood.rawValue, status: status.rawValue,
                                          activity: activity.rawValue) {
            savedEntry = created
            saveState = .saved
        } else {
            saveState = .error(store.error ?? "创建失败")
        }
    }

    private func lastSevenDates() -> [Int64] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            return Int64(date.timeIntervalSince1970)
        }
    }

    private func dayText(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func weekdayText(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        if Calendar.current.isDateInToday(date) { return "今天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "E"
        return f.string(from: date)
    }

    private func formatFullDate(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年MM月dd日 EEEE"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func relativeTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func toMarkdownString() -> String {
        var out = title.isEmpty ? "" : "# \(title)"
        if !content.isEmpty {
            if !out.isEmpty { out += "\n\n" }
            out += content
        }
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    private func toPlainTextString() -> String {
        title.isEmpty && content.isEmpty ? "" :
            title.isEmpty ? content :
            content.isEmpty ? title :
            "\(title)\n\n\(content)"
    }
}

private struct DiaryOption: Identifiable {
    let id: Int
    let icon: String?
    let title: String
}

private struct DiaryOptionGroup: View {
    let title: String
    let options: [DiaryOption]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            HStack(spacing: 5) {
                ForEach(options) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        HStack(spacing: 3) {
                            if let icon = option.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text(option.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            selected == option.id ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selected == option.id ? Color.accentColor : .secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selected == option.id ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
