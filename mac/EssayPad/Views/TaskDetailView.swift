import SwiftUI

struct TaskDetailView: View {
    let task: TodoTask
    @Binding var tasks: [TodoTask]
    @State private var title: String
    @State private var description: String
    @State private var progress: Int
    @State private var priority: Int
    @State private var dueAt: Date
    @State private var saving = false
    @State private var error: String?
    @State private var linkedNotes: [Note] = []
    @State private var linkedNotesLoading = false
    @State private var showAttachSheet = false
    var onClose: () -> Void
    var onNavigateToNote: (Int64) -> Void = { _ in }

    init(task: TodoTask, tasks: Binding<[TodoTask]>, onClose: @escaping () -> Void,
         onNavigateToNote: @escaping (Int64) -> Void = { _ in }) {
        self.task = task
        self._tasks = tasks
        self._title = State(initialValue: task.title)
        self._description = State(initialValue: task.description)
        self._progress = State(initialValue: task.progress)
        self._priority = State(initialValue: task.priority)
        self._dueAt = State(initialValue: Date(timeIntervalSince1970: TimeInterval(task.dueAt)))
        self.onClose = onClose
        self.onNavigateToNote = onNavigateToNote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: priorityIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(priorityTint)
                Text("任务详情")
                    .font(.title2.bold())
                Spacer()
                if saving {
                    ProgressView().scaleEffect(0.6)
                }
                Button {
                    Task { await save() }
                } label: {
                    Text("保存 ⌘S")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
            if let err = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err).font(.callout)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("标题", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("描述").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 14))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("进度").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(progress)%").font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(progressTint)
                        }
                        Slider(value: Binding(
                            get: { Double(progress) },
                            set: { progress = Int($0.rounded()) }
                        ), in: 0...100, step: 25)
                        .tint(progressTint)
                        HStack(spacing: 6) {
                            ForEach([0, 25, 50, 75, 100], id: \.self) { v in
                                Button {
                                    progress = v
                                } label: {
                                    Text("\(v)")
                                        .font(.system(size: 11, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(progress == v ? progressTint.opacity(0.25) : Color(nsColor: .controlBackgroundColor),
                                                    in: RoundedRectangle(cornerRadius: 5))
                                        .foregroundStyle(progress == v ? progressTint : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("优先级").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ForEach([0, 1, 2], id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: priorityIconFor(p))
                                        Text(priorityLabelFor(p))
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(priority == p ? priorityTintFor(p) : Color(nsColor: .controlBackgroundColor),
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(priority == p ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("所属日期").font(.caption).foregroundStyle(.secondary)
                        DatePicker("", selection: $dueAt, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        HStack {
                            Button("移到今天") {
                                let cal = Calendar.current
                                dueAt = cal.startOfDay(for: Date())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            if task.isOverdue {
                                Text("⚠️ 已延期")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    linkedNotesSection

                    VStack(alignment: .leading, spacing: 4) {
                        Text("创建于 \(formatTime(task.createdAt)) · 更新于 \(formatTime(task.updatedAt))")
                            .font(.caption).foregroundStyle(.tertiary)
                        if task.isDone {
                            Text("完成于 \(formatTime(task.completedAt))")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showAttachSheet) {
            AttachNoteSheet(linkedNoteIds: Set(linkedNotes.map { $0.id })) { noteId in
                Task { await attach(noteId) }
            }
        }
        .task {
            await reloadLinkedNotes()
        }
    }

    private var linkedNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("关联笔记").font(.caption).foregroundStyle(.secondary)
                if !linkedNotes.isEmpty {
                    Text("\(linkedNotes.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Button {
                    showAttachSheet = true
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if linkedNotesLoading {
                ProgressView().scaleEffect(0.6).frame(maxWidth: .infinity, minHeight: 24)
            } else if linkedNotes.isEmpty {
                Text("暂无关联笔记,点上方「添加」可绑定已有笔记")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(linkedNotes) { n in
                        linkedNoteRow(n)
                    }
                }
            }
        }
    }

    private func linkedNoteRow(_ n: Note) -> some View {
        HStack(spacing: 8) {
            Button {
                onNavigateToNote(n.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: n.categoryEnum.icon)
                        .foregroundStyle(n.categoryEnum.tint)
                        .font(.system(size: 12))
                        .frame(width: 16)
                    Text(n.title.isEmpty ? "无标题" : n.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.blue)
                        .font(.system(size: 11))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("跳转到笔记")

            Button {
                Task { await detach(n.id) }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("解绑")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }

    private func reloadLinkedNotes() async {
        linkedNotesLoading = true
        defer { linkedNotesLoading = false }
        do {
            linkedNotes = try await APIClient.shared.listTaskNotes(taskID: task.id)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func attach(_ noteId: Int64) async {
        do {
            try await APIClient.shared.attachNoteToTask(taskID: task.id, noteID: noteId)
            await reloadLinkedNotes()
            updateNoteCount(+1)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func detach(_ noteId: Int64) async {
        do {
            try await APIClient.shared.detachNoteFromTask(taskID: task.id, noteID: noteId)
            linkedNotes.removeAll { $0.id == noteId }
            updateNoteCount(-1)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func updateNoteCount(_ delta: Int) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            var t = tasks[idx]
            t.noteCount = max(0, t.noteCount + delta)
            tasks[idx] = t
        }
    }

    private var priorityIcon: String {
        priorityIconFor(priority)
    }
    private var priorityTint: Color { priorityTintFor(priority) }
    private var progressTint: Color {
        switch progress {
        case 100: return .green
        case 75: return .blue
        case 50: return .orange
        case 25: return .red
        default: return .gray
        }
    }

    private func priorityIconFor(_ p: Int) -> String {
        switch p {
        case 2: return "flame.fill"
        case 1: return "star.fill"
        default: return "circle"
        }
    }
    private func priorityLabelFor(_ p: Int) -> String {
        switch p {
        case 2: return "紧急"
        case 1: return "重要"
        default: return "普通"
        }
    }
    private func priorityTintFor(_ p: Int) -> Color {
        switch p {
        case 2: return .red
        case 1: return .orange
        default: return .gray
        }
    }

    private func formatTime(_ ts: Int64) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let newDueAt = Int64(Calendar.current.startOfDay(for: dueAt).timeIntervalSince1970)
            let updated = try await APIClient.shared.updateTask(
                id: task.id,
                title: title,
                description: description,
                progress: progress,
                priority: priority,
                dueAt: newDueAt
            )
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                var merged = updated
                merged.noteCount = tasks[idx].noteCount
                tasks[idx] = merged
            }
            error = nil
            onClose()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct AttachNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Note] = []
    @State private var loading = false
    @State private var searchText = ""
    let linkedNoteIds: Set<Int64>
    let onAttach: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("添加关联笔记").font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
            TextField("搜索…", text: $searchText)
                .textFieldStyle(.roundedBorder)
            if loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else if filtered.isEmpty {
                Text("没有可关联的笔记")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filtered) { n in
                            HStack(spacing: 8) {
                                Image(systemName: n.categoryEnum.icon)
                                    .foregroundStyle(n.categoryEnum.tint)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.title.isEmpty ? "无标题" : n.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Text(n.content.prefix(60))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("关联") {
                                    onAttach(n.id)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }
        }
        .padding(20)
        .frame(width: 480, height: 460)
        .task { await load() }
    }

    private var filtered: [Note] {
        let pool = candidates.filter { !linkedNoteIds.contains($0.id) }
        guard !searchText.isEmpty else { return pool }
        let kw = searchText.lowercased()
        return pool.filter {
            $0.title.lowercased().contains(kw) || $0.content.lowercased().contains(kw)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        var collected: [Note] = []
        for cat in NoteCategory.allCases {
            do {
                let (_, list) = try await APIClient.shared.listNotes(category: cat, page: 1, pageSize: 50)
                collected.append(contentsOf: list)
            } catch {
                continue
            }
        }
        candidates = collected.sorted { $0.updatedAt > $1.updatedAt }
    }
}