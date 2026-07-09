import Foundation

struct PomodoroSession: Codable, Identifiable, Equatable {
    let id: Int64
    var taskId: Int64
    var plannedMinutes: Int
    var actualMinutes: Int
    var status: Int
    var startedAt: Int64
    var endedAt: Int64
    var note: String

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case plannedMinutes = "planned_minutes"
        case actualMinutes = "actual_minutes"
        case status
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
        self.taskId = (try? c.decode(Int64.self, forKey: .taskId)) ?? 0
        self.plannedMinutes = (try? c.decode(Int.self, forKey: .plannedMinutes)) ?? 0
        self.actualMinutes = (try? c.decode(Int.self, forKey: .actualMinutes)) ?? 0
        self.status = (try? c.decode(Int.self, forKey: .status)) ?? 0
        self.startedAt = (try? c.decode(Int64.self, forKey: .startedAt)) ?? 0
        self.endedAt = (try? c.decode(Int64.self, forKey: .endedAt)) ?? 0
        self.note = (try? c.decode(String.self, forKey: .note)) ?? ""
    }

    var isRunning: Bool { status == 0 }
    var isCompleted: Bool { status == 1 }
    var isAborted: Bool { status == 2 }
}