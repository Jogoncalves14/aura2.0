import SwiftUI

enum ActionPriority: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var symbol: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "arrow.right"
        case .high: return "arrow.up"
        }
    }
}