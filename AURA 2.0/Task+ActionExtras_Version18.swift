import CoreData

// MARK: - Supporting Types

enum ActionPriority: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

// Internal wrapper for encoding labels as JSON.
private struct _LabelsWrapper: Codable {
    let labels: [String]
}

// MARK: - Task Action Extras

extension Task {

    // Present 'title' as 'actionName' (leave Core Data attribute name unchanged)
    var actionName: String {
        get {
            // If Core Data generated title as optional:
            if let mirror = Mirror(reflecting: self).children.first(where: { $0.label == "title" }) {
                if mirror.value is Optional<Any> { return title ?? "" }
            }
            return title  // if non-optional this compiles cleanly
        }
        set { title = newValue }
    }

    // Action Priority (renamed to avoid clash if another `priority` existed)
    var actionPriority: ActionPriority? {
        get { priorityRaw.flatMap { ActionPriority(rawValue: $0) } }
        set { priorityRaw = newValue?.rawValue }
    }

    // Labels stored as JSON inside labelsData
    var labelsArray: [String] {
        get {
            guard let data = labelsData else { return [] }
            do {
                let decoded = try JSONDecoder().decode(_LabelsWrapper.self, from: data)
                return decoded.labels
            } catch {
                return []
            }
        }
        set {
            // Normalize: trim, unique (case-insensitive), sort lexicographically
            let cleaned = Array(
                Set(
                    newValue
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )
            )
            .sorted { $0.lowercased() < $1.lowercased() }

            if cleaned.isEmpty {
                labelsData = nil
                return
            }
            do {
                let data = try JSONEncoder().encode(_LabelsWrapper(labels: cleaned))
                labelsData = data
            } catch {
                labelsData = nil
            }
        }
    }

    // Ensure createdAt/id exist
    func ensureCreatedAtAndID() {
        if createdAt == nil { createdAt = Date() }
        if id == nil { id = UUID() }
    }

    static func prepareForEditing(_ task: Task) {
        task.ensureCreatedAtAndID()
    }
}
extension Task {
    @NSManaged public var priorityRaw: String?
    @NSManaged public var labelsData: Data?
}
