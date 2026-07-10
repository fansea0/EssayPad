import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @State private var selection: Note?
    @State private var showEditor = false
    @State private var newEditorID: String? = nil
    @State private var searchText = ""
    @State private var showWeekly = false
    @State private var serverOnline = true
    @State private var showShortcuts = false
    @State private var mainMode: MainMode = .notes
    @State private var diaryStore = DiaryStore()

    @State private var tasks: [TodoTask] = []
    @State private var taskGroup: TaskGroup = .today
    @State private var tasksLoading = false
    @State private var taskLoadGeneration = 0
    @State private var detailTask: TodoTask?
    @State private var confettiAnchor: CGPoint?
    @State private var tasksError: String?
    @State private var pomodoroSetupTask: TodoTask? = nil
    @State private var pomodoroSetupFree: Bool = false

    enum MainMode { case notes, tasks, diary }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HeaderBar(title: "EssayPad",
                          subtitle: headerSubtitle,
                          subtitleIcon: headerSubtitleIcon)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                if mainMode == .notes {
                    NoteListView(selection: $selection, showEditor: $showEditor,
                                 searchText: $searchText, tasks: tasks)
                } else if mainMode == .diary {
                    DiarySidebarView(store: diaryStore)
                }

                Spacer(minLength: 0)

                ModeSwitcher(current: $mainMode)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }
            .frame(minWidth: 300)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            VStack(spacing: 0) {
                ZStack {
                    if showWeekly {
                        WeeklyReportView(onClose: { showWeekly = false })
                            .transition(.opacity)
                    } else if mainMode == .tasks {
                        tasksContainer
                    } else if mainMode == .diary {
                        diaryContainer
                    } else {
                        notesContainer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                StatusBar(totalCount: totalCount(),
                           serverOnline: serverOnline,
                           mainMode: mainMode)
            }
            .sheet(item: $pomodoroSetupTask) { task in
                PomodoroSetupView(task: task) { minutes in
                    pomodoroSetupTask = nil
                    PomodoroWindowController.shared.start(task: task, plannedMinutes: minutes)
                } onCancel: {
                    pomodoroSetupTask = nil
                }
            }
            .sheet(isPresented: $pomodoroSetupFree) {
                PomodoroSetupView(task: nil) { minutes in
                    pomodoroSetupFree = false
                    PomodoroWindowController.shared.start(task: nil, plannedMinutes: minutes)
                } onCancel: {
                    pomodoroSetupFree = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroFree)) { _ in
                pomodoroSetupFree = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroCountUp)) { _ in
                PomodoroWindowController.shared.startCountUp(task: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroRest)) { _ in
                PomodoroWindowController.shared.startRest(minutes: 5)
            }
        }
        .task {
            await store.load()
            serverOnline = await LocalServerManager.isRunning()
        }
        .onChange(of: showEditor) { _, new in
            newEditorID = "new-\(UUID().uuidString)"
        }
        .onChange(of: mainMode) { _, new in
            NSLog("[ES] ContentView mainMode=\(mainModeName(new))")
            if new == .diary {
                Task {
                    await diaryStore.load()
                    await diaryStore.openToday()
                }
            }
        }
        .onChange(of: store.notesByCategory) { _, _ in
            if let sel = selection {
                let allNotes = store.notesByCategory.values.flatMap { $0 }
                if let updated = allNotes.first(where: { $0.id == sel.id }), updated != sel {
                    NSLog("[ES] ContentView syncing selection id=\(sel.id) old_title=\(sel.title) new_title=\(updated.title)")
                    selection = updated
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showWeekly = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("AI 周报")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 4)
                }
                .help("基于近 7 天的随笔生成 AI 周报")
            }
            ToolbarItemGroup(placement: .navigation) {
                if mainMode == .notes {
                    TextField("搜索…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
        }
        .frame(minWidth: 880, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: .toggleShortcuts)) { _ in
            showShortcuts.toggle()
        }
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet()
        }
    }

    @ViewBuilder
    private var notesContainer: some View {
        if showEditor || selection != nil {
            NoteEditorView(note: showEditor ? nil : selection,
                           showEditor: $showEditor,
                           initialCategory: store.selectedCategory)
                .id(showEditor
                    ? (newEditorID ?? "new-init")
                    : "edit-\(selection?.id ?? 0)")
        } else {
            EmptyDetailView()
        }
    }

    @ViewBuilder
    private var tasksContainer: some View {
        TasksView(
            tasks: $tasks,
            selectedGroup: $taskGroup,
            loading: $tasksLoading,
            detailTask: $detailTask,
            confettiAnchor: $confettiAnchor,
            error: $tasksError,
            onLoad: { Task { await loadTasks(for: taskGroup) } },
            onNavigateToNote: { noteId in
                detailTask = nil
                mainMode = .notes
                Task { await openNote(noteId) }
            },
            onStartPomodoro: { task in
                pomodoroSetupTask = task
            }
        )
        .task(id: taskGroup) {
            await loadTasks(for: taskGroup)
        }
    }

    private var diaryContainer: some View {
        DiaryEditorView(store: diaryStore)
            .id("diary-\(diaryStore.selectedEntry?.id ?? 0)-\(diaryStore.selectedDate)")
    }

    private func loadTasks(for group: TaskGroup) async {
        taskLoadGeneration += 1
        let generation = taskLoadGeneration
        NSLog("[ES] loadTasks START group=\(group.rawValue) generation=\(generation) tasks.count=\(tasks.count)")
        tasksLoading = true
        defer {
            if taskLoadGeneration == generation {
                tasksLoading = false
                NSLog("[ES] loadTasks END group=\(group.rawValue) generation=\(generation) tasks.count=\(tasks.count)")
            }
        }
        do {
            let result = try await APIClient.shared.listTasks(group: group)
            // A cancelled or outdated request must not replace the visible task list.
            guard !Task.isCancelled,
                  taskLoadGeneration == generation,
                  TaskLoadPolicy.shouldApply(
                      requestedGroup: group,
                      selectedGroup: taskGroup,
                      isTasksMode: mainMode == .tasks
                  ) else {
                return
            }
            let titles = result.map { "id=\($0.id) title='\($0.title)' priority=\($0.priority) status=\($0.status)" }.joined(separator: " | ")
            NSLog("[ES] loadTasks GOT \(result.count) tasks: [\(titles)]")
            tasks = result
            tasksError = nil
        } catch is CancellationError {
            return
        } catch {
            guard taskLoadGeneration == generation,
                  TaskLoadPolicy.shouldApply(
                      requestedGroup: group,
                      selectedGroup: taskGroup,
                      isTasksMode: mainMode == .tasks
                  ) else {
                return
            }
            NSLog("[ES] loadTasks FAIL group=\(group.rawValue): \(error)")
            tasksError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func totalCount() -> Int {
        store.notesByCategory.values.reduce(0) { $0 + $1.count }
    }

    private var headerSubtitle: String {
        switch mainMode {
        case .notes:
            return store.selectedCategory.name
        case .tasks:
            return "任务面板"
        case .diary:
            return "日记"
        }
    }

    private var headerSubtitleIcon: String {
        switch mainMode {
        case .notes:
            return store.selectedCategory.icon
        case .tasks:
            return "checklist"
        case .diary:
            return "book.closed"
        }
    }

    private func mainModeName(_ mode: MainMode) -> String {
        switch mode {
        case .notes:
            return "notes"
        case .tasks:
            return "tasks"
        case .diary:
            return "diary"
        }
    }

    private func openNote(_ id: Int64) async {
        do {
            let note = try await APIClient.shared.getNote(id: id)
            if let cat = NoteCategory(rawValue: note.category) {
                store.selectedCategory = cat
            }
            selection = note
            showEditor = false
        } catch {
            tasksError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct HeaderBar: View {
    let title: String
    let subtitle: String
    let subtitleIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                Image(systemName: subtitleIcon)
                    .foregroundStyle(Color.accentColor)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusBar: View {
    let totalCount: Int
    let serverOnline: Bool
    let mainMode: ContentView.MainMode

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(serverOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )
            Text(serverOnline ? "后端在线" : "后端离线")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider().frame(height: 12)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("⌥Space 快速记一笔")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusText: String {
        switch mainMode {
        case .notes:
            return "总笔记 \(totalCount) 条"
        case .tasks:
            return "任务面板"
        case .diary:
            return "日记"
        }
    }
}

private struct ModeSwitcher: View {
    @Binding var current: ContentView.MainMode

    var body: some View {
        HStack(spacing: 0) {
            modeButton(.notes, icon: "note.text", label: "笔记")
            modeButton(.tasks, icon: "checklist", label: "任务")
            modeButton(.diary, icon: "book.closed", label: "日记")
        }
        .padding(2)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func modeButton(_ mode: ContentView.MainMode, icon: String, label: String) -> some View {
        Button {
            current = mode
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 20)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                current == mode ? Color.accentColor : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .foregroundStyle(current == mode ? Color.white : Color.primary)
            .contentShape(Rectangle())   // 关键:让整个矩形都接收点击,不止图标/文字
        }
        .buttonStyle(.plain)
        .help(helpText(for: mode))
    }

    private func helpText(for mode: ContentView.MainMode) -> String {
        switch mode {
        case .notes:
            return "切换到笔记"
        case .tasks:
            return "切换到任务"
        case .diary:
            return "切换到日记"
        }
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("还没有内容")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("按 ⌥Space 快速记一笔,或点列表 + 新建")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
