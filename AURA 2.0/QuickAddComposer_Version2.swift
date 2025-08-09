import SwiftUI
import CoreData

struct QuickAddComposer: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var userDomain: UserDomain
    @FocusState private var focused: Bool

    @Binding var isPresented: Bool

    @State private var text: String = ""
    @State private var project: String = ""
    @State private var dueDate: Date? = nil
    @State private var notes: String = ""
    @State private var showDetails = false
    @State private var saving = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }

            // Composer Card
            VStack(spacing: 0) {
                dragHandle
                inputArea
                if showDetails { details }
                actionBar
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.20), radius: 22, x: 0, y: 12)
            )
            .frame(maxWidth: 640)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { focused = true }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isPresented)
    }

    // MARK: - Components
    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 46, height: 5)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .accessibilityHidden(true)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Add a task (e.g. 'Email Sarah tomorrow #Sales')", text: $text, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit { save() }

            HStack(spacing: 10) {
                SmallButton(icon: "folder", label: projectLabel, active: !project.isEmpty) {
                    withAnimation {
                        if project.isEmpty { project = suggestedProject() } else { project = "" }
                    }
                }
                SmallButton(icon: "calendar", label: dueDateLabel, active: dueDate != nil) {
                    withAnimation {
                        if dueDate == nil {
                            dueDate = Date()
                        } else {
                            dueDate = nil
                        }
                    }
                }
                SmallButton(icon: "ellipsis", label: showDetails ? "Less" : "More", active: showDetails) {
                    withAnimation { showDetails.toggle() }
                }
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var details: some View {
        VStack(spacing: 14) {
            TextField("Project name", text: $project)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Due Date")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if dueDate != nil {
                        Button(role: .destructive) {
                            withAnimation { dueDate = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear due date")
                    }
                }
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .opacity(dueDate == nil ? 0.35 : 1)
                .disabled(dueDate == nil)
            }

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var actionBar: some View {
        HStack {
            Button(role: .cancel) {
                withAnimation { isPresented = false }
            } label: { Text("Cancel") }

            Spacer()

            Button {
                save()
            } label: {
                HStack(spacing: 6) {
                    if saving { ProgressView().scaleEffect(0.75) }
                    Text("Add")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(canSave ? Color.blue : Color.gray.opacity(0.35))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(!canSave || saving)
        }
        .padding(.top, 16)
    }

    // MARK: - Computed
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var projectLabel: String { project.isEmpty ? "Project" : project }
    private var dueDateLabel: String {
        if let dueDate {
            return dueDate.formatted(date: .abbreviated, time: .omitted)
        }
        return "Due"
    }
    private func suggestedProject() -> String { "General" }

    // MARK: - Save
    private func save() {
        guard canSave else { return }
        saving = true

        // Parse tokens (#project, simple date words)
        let parsed = ParsedInputParser.parse(text)
        var finalProject = project
        if finalProject.isEmpty, let p = parsed.project { finalProject = p }
        if dueDate == nil, let d = parsed.due { dueDate = d }

        let task = Task(context: viewContext)
        task.id = UUID()
        task.title = parsed.title
        task.status = TaskStatus.inbox.rawValue
        task.createdAt = Date()
        if let dom = userDomain.selectedDomain?.rawValue {
            task.domain = dom
        }
        if !finalProject.isEmpty { task.project = finalProject }
        if let dueDate { task.dueDate = dueDate }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.notes = notes
        }

        do {
            try viewContext.save()
            withAnimation {
                isPresented = false
            }
        } catch {
            print("QuickAdd save error: \(error)")
        }
        saving = false
    }
}

// MARK: - SmallButton
fileprivate struct SmallButton: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Color.blue.opacity(0.16) : Color(.systemGray6))
            .foregroundColor(active ? .blue : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Parser
fileprivate struct ParsedInputParser {
    static func parse(_ text: String) -> (title: String, project: String?, due: Date?) {
        var p: String?
        var d: Date?
        let tokens = text.split(separator: " ").map(String.init)
        var remainder: [String] = []
        for token in tokens {
            if token.first == "#", token.count > 1 {
                p = String(token.dropFirst())
                continue
            }
            if let dd = interpretDateToken(token.lowercased()) {
                d = dd
                continue
            }
            remainder.append(token)
        }
        return (remainder.joined(separator: " "), p, d)
    }

    private static func interpretDateToken(_ token: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch token {
        case "today": return now
        case "tomorrow": return cal.date(byAdding: .day, value: 1, to: now)
        case "nextweek", "next-week": return cal.date(byAdding: .day, value: 7, to: now)
        default: return nil
        }
    }
}