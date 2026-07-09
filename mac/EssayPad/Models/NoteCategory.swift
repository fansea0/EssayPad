import Foundation
import SwiftUI

enum NoteCategory: Int, Codable, CaseIterable, Identifiable {
    case bug = 1
    case requirement = 2
    case idea = 3
    case draft = 4

    var id: Int { rawValue }
    var name: String {
        switch self {
        case .bug: return "bug"
        case .requirement: return "需求"
        case .idea: return "想法"
        case .draft: return "草稿"
        }
    }
    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .requirement: return "list.bullet.rectangle"
        case .idea: return "lightbulb"
        case .draft: return "tray.full"
        }
    }
    var tint: Color {
        switch self {
        case .bug: return Color(red: 0.92, green: 0.30, blue: 0.30)
        case .requirement: return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .idea: return Color(red: 0.95, green: 0.70, blue: 0.20)
        case .draft: return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}