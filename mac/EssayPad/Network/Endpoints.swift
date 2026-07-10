import Foundation

enum APIConfig {
    static let baseURL = URL(string: "http://127.0.0.1:18888")!
}

enum Endpoints {
    static let notes = APIConfig.baseURL.appendingPathComponent("/api/v1/notes")
    static let diaries = APIConfig.baseURL.appendingPathComponent("/api/v1/diaries")
    static let diaryByDate = APIConfig.baseURL.appendingPathComponent("/api/v1/diaries/by-date")
    static let weeklyGenerate = APIConfig.baseURL.appendingPathComponent("/api/v1/weekly/generate")
    static let tasks = APIConfig.baseURL.appendingPathComponent("/api/v1/tasks")

    static func noteDetail(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/notes/\(id)")
    }

    static func diaryDetail(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/diaries/\(id)")
    }

    static func taskDetail(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(id)")
    }

    static func taskProgress(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(id)/progress")
    }

    static func taskComplete(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(id)/complete")
    }

    static func taskMoveToToday(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(id)/move-to-today")
    }

    static func taskNotes(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(id)/notes")
    }

    static func taskNote(taskID: Int64, noteID: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/tasks/\(taskID)/notes/\(noteID)")
    }

    static let pomodoros = APIConfig.baseURL.appendingPathComponent("/api/v1/pomodoros")

    static func pomodoroComplete(id: Int64) -> URL {
        APIConfig.baseURL.appendingPathComponent("/api/v1/pomodoros/\(id)/complete")
    }

    static let aiConfig = APIConfig.baseURL.appendingPathComponent("/api/v1/ai-config")
    static let aiConfigStats = APIConfig.baseURL.appendingPathComponent("/api/v1/ai-config/stats")
}

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let msg: String
    let data: T?
}
