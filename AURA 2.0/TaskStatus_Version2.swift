import SwiftUI

// Your defined statuses (raw values with spaces retained)
enum TaskStatus: String, CaseIterable, Codable {
    case inbox = "Inbox"
    case todo = "To-do"
    case inProgress = "In Progress"
    case overdue = "Overdue"
    case needsReview = "Needs Review"
    case completed = "Completed"

    var symbol: String {
        switch self {
        case .inbox: return "tray"
        case .todo: return "list.bullet"
        case .inProgress: return "play.circle"
        case .overdue: return "exclamationmark.triangle"
        case .needsReview: return "eye"
        case .completed: return "checkmark.circle"
        }
    }
    var tint: Color {
        switch self {
        case .inbox: return .blue
        case .todo: return .orange
        case .inProgress: return .purple
        case .overdue: return .red
        case .needsReview: return .teal
        case .completed: return .green
        }
    }
}
