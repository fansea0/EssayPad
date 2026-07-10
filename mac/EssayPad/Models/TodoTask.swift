import Foundation

struct TodoTask: Codable, Identifiable, Equatable {
    let id: Int64
    var title: String
    var description: String
    var progress: Int
    var priority: Int
    var status: Int
    var dueAt: Int64
    let createdAt: Int64
    var updatedAt: Int64
    var completedAt: Int64
    var noteCount: Int
    var pomodoroCount: Int
    var pomodoroMinutes: Int

    enum CodingKeys: String, CodingKey {
        case id, title, description, progress, priority, status
        case dueAt = "due_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case noteCount = "note_count"
        case pomodoroCount = "pomodoro_count"
        case pomodoroMinutes = "pomodoro_minutes"
    }

    init(id: Int64, title: String, description: String, progress: Int,
         priority: Int, status: Int, dueAt: Int64, createdAt: Int64,
         updatedAt: Int64, completedAt: Int64, noteCount: Int = 0,
         pomodoroCount: Int = 0, pomodoroMinutes: Int = 0) {
        self.id = id
        self.title = title
        self.description = description
        self.progress = progress
        self.priority = priority
        self.status = status
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.noteCount = noteCount
        self.pomodoroCount = pomodoroCount
        self.pomodoroMinutes = pomodoroMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.progress = (try? c.decode(Int.self, forKey: .progress)) ?? 0
        self.priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        self.status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        self.dueAt = (try? c.decode(Int64.self, forKey: .dueAt)) ?? 0
        self.createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
        self.updatedAt = (try? c.decode(Int64.self, forKey: .updatedAt)) ?? 0
        self.completedAt = (try? c.decode(Int64.self, forKey: .completedAt)) ?? 0
        self.noteCount = (try? c.decode(Int.self, forKey: .noteCount)) ?? 0
        self.pomodoroCount = (try? c.decode(Int.self, forKey: .pomodoroCount)) ?? 0
        self.pomodoroMinutes = (try? c.decode(Int.self, forKey: .pomodoroMinutes)) ?? 0
    }

    var isDone: Bool { status == 1 }
    var isAbandoned: Bool { status == 2 }

    var isOverdue: Bool {
        if isDone || isAbandoned { return false }
        let todayStart = Int64(Date().timeIntervalSince1970) / 86400 * 86400
        return dueAt > 0 && dueAt < todayStart
    }
}

enum TaskGroup: String, CaseIterable, Identifiable {
    case today, yesterday, week, all, longTerm = "long_term"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .week: return "本周"
        case .all: return "全部"
        case .longTerm: return "长期"
        }
    }
}

enum TaskPriority: Int {
    case normal = 0
    case important = 1
    case urgent = 2
}

enum TaskLoadPolicy {
    static func shouldApply(requestedGroup: TaskGroup, selectedGroup: TaskGroup, isTasksMode: Bool) -> Bool {
        isTasksMode && requestedGroup == selectedGroup
    }
}
