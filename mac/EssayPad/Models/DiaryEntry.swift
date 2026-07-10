import Foundation

struct DiaryEntry: Codable, Identifiable, Hashable {
    let id: Int64
    let userId: Int64
    let diaryDate: Int64
    var title: String
    var content: String
    var mood: Int
    var status: Int
    var activity: Int
    let createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case diaryDate = "diary_date"
        case title, content, mood, status, activity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var moodName: String { DiaryMood(rawValue: mood)?.name ?? "未选" }
    var statusName: String { DiaryStatus(rawValue: status)?.name ?? "未选" }
    var activityName: String { DiaryActivity(rawValue: activity)?.name ?? "未选" }

    var summary: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "还没有正文" : String(trimmed.prefix(80))
    }
}

enum DiaryListMode: String, CaseIterable, Identifiable {
    case all
    case week

    var id: String { rawValue }
    var name: String {
        switch self {
        case .all: return "全部"
        case .week: return "本周"
        }
    }
}

enum DiaryMood: Int, CaseIterable, Identifiable {
    case none = 0
    case happy = 1
    case calm = 2
    case down = 3
    case anxious = 4

    var id: Int { rawValue }
    var name: String {
        switch self {
        case .none: return "未选"
        case .happy: return "开心"
        case .calm: return "平静"
        case .down: return "低落"
        case .anxious: return "焦虑"
        }
    }
    var icon: String {
        switch self {
        case .none: return "circle"
        case .happy: return "sun.max"
        case .calm: return "leaf"
        case .down: return "cloud.rain"
        case .anxious: return "waveform.path.ecg"
        }
    }
}

enum DiaryStatus: Int, CaseIterable, Identifiable {
    case none = 0
    case excellent = 1
    case good = 2
    case normal = 3
    case poor = 4
    case bad = 5

    var id: Int { rawValue }
    var name: String {
        switch self {
        case .none: return "未选"
        case .excellent: return "很好"
        case .good: return "较好"
        case .normal: return "普通"
        case .poor: return "较差"
        case .bad: return "很差"
        }
    }
}

enum DiaryActivity: Int, CaseIterable, Identifiable {
    case none = 0
    case work = 1
    case study = 2
    case travel = 3
    case rest = 4
    case game = 5

    var id: Int { rawValue }
    var name: String {
        switch self {
        case .none: return "未选"
        case .work: return "工作"
        case .study: return "学习"
        case .travel: return "出游"
        case .rest: return "休息"
        case .game: return "游戏"
        }
    }
    var icon: String {
        switch self {
        case .none: return "circle"
        case .work: return "briefcase"
        case .study: return "book"
        case .travel: return "map"
        case .rest: return "sofa"
        case .game: return "gamecontroller"
        }
    }
}
