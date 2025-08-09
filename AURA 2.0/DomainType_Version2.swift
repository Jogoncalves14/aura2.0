import SwiftUI

// Placeholder if you already have a real DomainType, delete this file.
enum DomainType: String, CaseIterable, Identifiable {
    case Work, Personal, Learning
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .Work: return "briefcase"
        case .Personal: return "person"
        case .Learning: return "book"
        }
    }
}
