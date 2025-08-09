import SwiftUI
import CoreData

struct QuickAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var userDomain: UserDomain
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFocused: Bool

    @State private var rawText: String = ""
    @State private var showProject = false
    @State private var showNotes = false
    @State private var project: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date? = nil
    @State private var showDatePicker = false
    @State private var saving = false
    @State private var showEmptyAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $rawText)
                            .frame(minHeight: 90)
                            .focused($isFocused)
                            .overlay(
                                Group {
                                    if rawText.isEmpty {
                                        Text("What’s the task? (e.g. 'Call John tomorrow #Marketing')")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )
                    }
                }

                quickTogglesSection

                if showProject {
                    Section("Project") {
                        TextField("Project name", text: $project)
                            .textInputAutocapitalization(.words)
                    }
                }

                if showDatePicker {
                    Section("Due Date") {
                        DatePicker("Due", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date])
                        Button(role: .destructive) {
                            withAnimation { dueDate = nil; showDatePicker = false }
                        } label: {
                            Label("Clear Date", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                if showNotes {
                    Section("Notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if saving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                }
            }
            .alert("Empty Task", isPresented: $showEmptyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a title.")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
        }
    }

    private var quickTogglesSection: some View {
        Section("Quick Options") {
            HStack(spacing: 10) {
                ToggleCapsule(active: showProject, label: "Project", icon: "folder") {
                    withAnimation { showProject.toggle() }
                }
                ToggleCapsule(active: showDatePicker, label: dueDateLabel, icon: "calendar") {
                    withAnimation {
                        showDatePicker.toggle()
                        if dueDate == nil { dueDate = Date() }
                    }
                }
                ToggleCapsule(active: showNotes, label: "Notes", icon: "square.and.pencil") {
                    withAnimation { showNotes.toggle() }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 4)
        }
    }

    private var dueDateLabel: String {
        if let dueDate {
            return dueDate.formatted(date: .abbreviated, time: .omitted)
        }
        return "Due"
    }

    private func save() {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyAlert = true
            return
        }

        saving = true

        // Parse inline tokens (#project, tomorrow, next week)
        var parsedProject = project
        var parsedDue = dueDate
        let (title, inlineProject, inlineDue) = ParsedInputParser.parse(trimmed)
        if parsedProject.isEmpty, let p = inlineProject { parsedProject = p }
        if parsedDue == nil, let d = inlineDue { parsedDue = d }

        let newTask = Task(context: viewContext)
        newTask.id = UUID()
        newTask.title = title
        newTask.status = TaskStatus.inbox.rawValue
        newTask.createdAt = Date()
        if let dom = userDomain.selectedDomain?.rawValue {
            newTask.domain = dom
        }
        if !parsedProject.isEmpty {
            newTask.project = parsedProject
        }
        if let parsedDue {
            newTask.dueDate = parsedDue
        }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newTask.notes = notes
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("QuickAdd save error:", error)
            saving = false
        }
    }
}

// MARK: - Capsule Toggle
fileprivate struct ToggleCapsule: View {
    let active: Bool
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(active ? Color.blue.opacity(0.12) : Color(.systemGray6))
            .foregroundColor(active ? .blue : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Parsed Input Helper
fileprivate struct ParsedInputParser {
    static func parse(_ text: String) -> (title: String, project: String?, due: Date?) {
        var tokens = text.split(separator: " ").map(String.init)
        var project: String?
        var due: Date?

        var remaining: [String] = []
        for token in tokens {
            if token.hasPrefix("#") && token.count > 1 {
                project = String(token.dropFirst())
                continue
            }
            if let d = interpretDateToken(token.lowercased()) {
                due = d
                continue
            }
            remaining.append(token)
        }
        return (remaining.joined(separator: " "), project, due)
    }

    private static func interpretDateToken(_ token: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch token {
        case "today":
            return now
        case "tomorrow":
            return cal.date(byAdding: .day, value: 1, to: now)
        case "nextweek", "next-week":
            return cal.date(byAdding: .day, value: 7, to: now)
        default:
            return nil
        }
    }
}
