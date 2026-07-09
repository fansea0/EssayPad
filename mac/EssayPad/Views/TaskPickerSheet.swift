import SwiftUI

struct TaskPickerSheet: View {
    let currentTaskID: Int64?
    let onPick: (TodoTask?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tasks: [TodoTask] = []
    @State private var searchText = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 380, height: 460)
        .task { await loadTasks() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("切换任务")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            TextField("搜索任务…", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("重试") {
                    Task { await loadTasks() }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    pickerRow(title: "自由专注", subtitle: "不关联任务", icon: "timer", selected: currentTaskID == nil) {
                        onPick(nil)
                        dismiss()
                    }

                    ForEach(filteredTasks) { task in
                        pickerRow(
                            title: task.title,
                            subtitle: task.description.isEmpty ? "累计 \(task.pomodoroMinutes)m" : task.description,
                            icon: "checklist",
                            selected: currentTaskID == task.id
                        ) {
                            onPick(task)
                            dismiss()
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    private var filteredTasks: [TodoTask] {
        let active = tasks.filter { !$0.isDone && !$0.isAbandoned }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return active }
        return active.filter {
            $0.title.localizedStandardContains(keyword) ||
                $0.description.localizedStandardContains(keyword)
        }
    }

    private func pickerRow(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func loadTasks() async {
        loading = true
        defer { loading = false }
        do {
            tasks = try await APIClient.shared.listTasks(group: .all)
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
