import Foundation

enum WeeklyPreset: String {
    case today
    case yesterday
    case week
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case http(Int, String)
    case decode(String)
    case server(code: Int, msg: String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL 非法"
        case .http(let s, let m): return "HTTP \(s): \(m)"
        case .decode(let m): return "解析失败: \(m)"
        case .server(_, let m): return m
        case .underlying(let e): return e.localizedDescription
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func request<T: Decodable>(
        _ url: URL, method: String, body: Encodable? = nil
    ) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            if let bodyData = req.httpBody, !bodyData.isEmpty, bodyData.count < 2000 {
                NSLog("[ES] request \(method) \(url.path) body=\(String(data: bodyData, encoding: .utf8) ?? "<err>")")
            }
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.http(0, "no response")
        }
        if !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            let env = try JSONDecoder().decode(APIResponse<T>.self, from: data)
            if env.code != 0 {
                throw APIError.server(code: env.code, msg: env.msg)
            }
            guard let payload = env.data else {
                throw APIError.decode("empty data")
            }
            return payload
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.decode(error.localizedDescription)
        }
    }

    func listNotes(category: NoteCategory, page: Int = 1, pageSize: Int = 20) async throws -> (Int, [Note]) {
        var comps = URLComponents(url: Endpoints.notes, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "category", value: String(category.rawValue)),
            .init(name: "page", value: String(page)),
            .init(name: "page_size", value: String(pageSize)),
        ]
        struct R: Decodable { let total: Int; let list: [Note] }
        let r: R = try await request(comps.url!, method: "GET")
        return (r.total, r.list)
    }

    func getNote(id: Int64) async throws -> Note {
        try await request(Endpoints.noteDetail(id: id), method: "GET")
    }

    func createNote(category: NoteCategory, title: String, content: String, taskId: Int64 = 0) async throws -> Note {
        struct Body: Encodable { let category: Int; let title: String; let content: String; let task_id: Int64 }
        return try await request(Endpoints.notes, method: "POST",
                                 body: Body(category: category.rawValue, title: title, content: content, task_id: taskId))
    }

    func updateNote(id: Int64, title: String?, content: String?, category: NoteCategory?) async throws -> Note {
        struct Body: Encodable {
            let title: String
            let content: String
            let category: Int
        }
        return try await request(Endpoints.noteDetail(id: id), method: "PUT",
                                 body: Body(
                                    title: title ?? "",
                                    content: content ?? "",
                                    category: category?.rawValue ?? 0
                                 ))
    }

    func deleteNote(id: Int64) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request(Endpoints.noteDetail(id: id), method: "DELETE")
    }

    struct WeeklyReport: Codable {
        let id: Int64
        let preset: String
        let rangeStart: Int64
        let rangeEnd: Int64
        let summary: String
        let highlights: [String]
        let actionItems: [String]
        let noteCount: Int
        let createdAt: Int64
        let fromCache: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case preset
            case rangeStart = "range_start"
            case rangeEnd = "range_end"
            case summary
            case highlights
            case actionItems = "action_items"
            case noteCount = "note_count"
            case createdAt = "created_at"
            case fromCache = "from_cache"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? c.decode(Int64.self, forKey: .id)) ?? 0
            self.preset = (try? c.decode(String.self, forKey: .preset)) ?? ""
            self.rangeStart = (try? c.decode(Int64.self, forKey: .rangeStart)) ?? 0
            self.rangeEnd = (try? c.decode(Int64.self, forKey: .rangeEnd)) ?? 0
            self.summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
            self.highlights = (try? c.decode([String].self, forKey: .highlights)) ?? []
            self.actionItems = (try? c.decode([String].self, forKey: .actionItems)) ?? []
            self.noteCount = (try? c.decode(Int.self, forKey: .noteCount)) ?? 0
            self.createdAt = (try? c.decode(Int64.self, forKey: .createdAt)) ?? 0
            self.fromCache = try? c.decode(Bool.self, forKey: .fromCache)
        }
    }

    func generateWeekly(preset: WeeklyPreset = .week, force: Bool = false) async throws -> WeeklyReport {
        struct Body: Encodable { let preset: String; let force: Bool }
        return try await request(Endpoints.weeklyGenerate, method: "POST",
                                 body: Body(preset: preset.rawValue, force: force))
    }

    func listTasks(group: TaskGroup = .today) async throws -> [TodoTask] {
        var comps = URLComponents(url: Endpoints.tasks, resolvingAgainstBaseURL: false)!
        comps.queryItems = [.init(name: "group", value: group.rawValue)]
        struct R: Decodable { let total: Int; let list: [TodoTask] }
        let r: R = try await request(comps.url!, method: "GET")
        return r.list
    }

    func getTask(id: Int64) async throws -> TodoTask {
        try await request(Endpoints.taskDetail(id: id), method: "GET")
    }

    func createTask(title: String, description: String = "", priority: Int = 0,
                    dueAt: Int64 = 0) async throws -> TodoTask {
        struct Body: Encodable {
            let title: String
            let description: String
            let priority: Int
            let dueAt: Int64
            enum CodingKeys: String, CodingKey {
                case title, description, priority
                case dueAt = "due_at"
            }
        }
        let body = Body(title: title, description: description, priority: priority, dueAt: dueAt)
        return try await request(Endpoints.tasks, method: "POST", body: body)
    }

    func updateTask(id: Int64, title: String? = nil, description: String? = nil,
                    progress: Int? = nil, priority: Int? = nil,
                    dueAt: Int64? = nil, status: Int? = nil) async throws -> TodoTask {
        struct Body: Encodable {
            let title: String?
            let description: String?
            let progress: Int?
            let priority: Int?
            let dueAt: Int64?
            let status: Int?
            enum CodingKeys: String, CodingKey {
                case title, description, progress, priority, status
                case dueAt = "due_at"
            }
        }
        let body = Body(title: title, description: description, progress: progress,
                        priority: priority, dueAt: dueAt, status: status)
        return try await request(Endpoints.taskDetail(id: id), method: "PUT", body: body)
    }

    func updateTaskProgress(id: Int64, progress: Int) async throws -> TodoTask {
        struct Body: Encodable { let progress: Int }
        return try await request(Endpoints.taskProgress(id: id), method: "POST",
                                 body: Body(progress: progress))
    }

    func completeTask(id: Int64) async throws -> TodoTask {
        return try await request(Endpoints.taskComplete(id: id), method: "POST",
                                 body: Optional<String>.none)
    }

    func moveTaskToToday(id: Int64) async throws -> TodoTask {
        return try await request(Endpoints.taskMoveToToday(id: id), method: "POST",
                                 body: Optional<String>.none)
    }

    func deleteTask(id: Int64) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request(Endpoints.taskDetail(id: id), method: "DELETE")
    }

    func listTaskNotes(taskID: Int64) async throws -> [Note] {
        struct R: Decodable { let total: Int; let list: [Note] }
        let r: R = try await request(Endpoints.taskNotes(id: taskID), method: "GET")
        return r.list
    }

    func attachNoteToTask(taskID: Int64, noteID: Int64) async throws {
        struct Body: Encodable { let note_id: Int64 }
        struct OK: Decodable {}
        let _: OK = try await request(Endpoints.taskNotes(id: taskID), method: "POST",
                                      body: Body(note_id: noteID))
    }

    func detachNoteFromTask(taskID: Int64, noteID: Int64) async throws {
        struct OK: Decodable {}
        let _: OK = try await request(Endpoints.taskNote(taskID: taskID, noteID: noteID), method: "DELETE")
    }

    func createPomodoro(taskId: Int64, plannedMinutes: Int) async throws -> Int64 {
        struct Body: Encodable { let task_id: Int64; let planned_minutes: Int }
        struct R: Decodable { let id: Int64 }
        let r: R = try await request(Endpoints.pomodoros, method: "POST",
                                     body: Body(task_id: taskId, planned_minutes: plannedMinutes))
        return r.id
    }

    func completePomodoro(id: Int64, actualMinutes: Int, status: Int) async throws -> PomodoroSession {
        struct Body: Encodable { let actual_minutes: Int; let status: Int }
        return try await request(Endpoints.pomodoroComplete(id: id), method: "POST",
                                 body: Body(actual_minutes: actualMinutes, status: status))
    }

    func listPomodoros(taskId: Int64, days: Int = 30) async throws -> [PomodoroSession] {
        var comps = URLComponents(url: Endpoints.pomodoros, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "task_id", value: String(taskId)),
            .init(name: "days", value: String(days)),
        ]
        struct R: Decodable { let total: Int; let list: [PomodoroSession] }
        let r: R = try await request(comps.url!, method: "GET")
        return r.list
    }

    /// 更新 AI 服务配置(BaseURL / API Key / Model)
    func updateAIConfig(baseURL: String, apiKey: String, model: String) async throws {
        struct Body: Encodable {
            let baseURL: String
            let apiKey: String
            let model: String
            enum CodingKeys: String, CodingKey {
                case baseURL = "base_url"
                case apiKey = "api_key"
                case model
            }
        }
        struct OK: Decodable {}
        let _: OK = try await request(
            Endpoints.aiConfig, method: "PUT",
            body: Body(baseURL: baseURL, apiKey: apiKey, model: model)
        )
    }

    /// AI 调用量统计
    struct AIStats: Decodable {
        let totalCalls: Int64
        let success: Int64
        let failed: Int64
        let promptTokens: Int64
        let completionTokens: Int64
        let totalTokens: Int64
        let lastCallAt: Int64
        let lastError: String?
        let lastUsage: TokenUsage?
        let recent: [CallLog]

        enum CodingKeys: String, CodingKey {
            case totalCalls = "total_calls"
            case success, failed
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case lastCallAt = "last_call_at"
            case lastError = "last_error"
            case lastUsage = "last_usage"
            case recent
        }

        struct TokenUsage: Decodable {
            let promptTokens: Int64
            let completionTokens: Int64
            let totalTokens: Int64
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }

        struct CallLog: Decodable {
            let at: Int64
            let success: Bool
            let error: String?
            let usage: TokenUsage?
        }
    }

    func fetchAIStats() async throws -> AIStats {
        try await request(Endpoints.aiConfigStats, method: "GET")
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ v: Encodable) { self.value = v }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
