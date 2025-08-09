import CoreData

extension Task {
    func initializeDefaultStatus(defaultDueDate: Date = Date()) {
        if createdAt == nil { createdAt = Date() }
        if dueDate == nil { dueDate = defaultDueDate }
        if isCompleted {
            status = TaskStatus.completed.rawValue
        } else if status == nil {
            status = TaskStatus.inbox.rawValue
        }
    }

    func autoUpdateStatus(calendar: Calendar = .current,
                          preserveProgressStates: Bool = true) {
        if dueDate == nil { dueDate = Date() }
        guard let raw = status, let current = TaskStatus(rawValue: raw) else {
            status = TaskStatus.inbox.rawValue
            return
        }

        if isCompleted { status = TaskStatus.completed.rawValue; return }

        if let due = dueDate, due < calendar.startOfDay(for: Date()) {
            status = TaskStatus.overdue.rawValue
            return
        }

        if preserveProgressStates && (current == .inProgress || current == .needsReview) {
            status = current.rawValue
            return
        }

        if current == .inbox {
            if let due = dueDate, calendar.isDateInToday(due) {
                status = TaskStatus.inbox.rawValue
            } else {
                status = TaskStatus.todo.rawValue
            }
            return
        }

        if current == .overdue { status = TaskStatus.todo.rawValue; return }
        // Leave todo as is; default fallback:
        if status == nil { status = TaskStatus.todo.rawValue }
    }
}
