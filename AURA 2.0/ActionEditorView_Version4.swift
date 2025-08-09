import SwiftUI
import CoreData

struct ActionEditorView: View {
    @ObservedObject var task: Task
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Editable fields
    @State private var actionName: String = ""
    @State private var dueDate: Date? = nil
    @State private var project: String = ""
    @State private var labels: [String] = []
    @State private var priority: ActionPriority? = nil

    // Non-edit fields (display only if desired)
    @State private var isCompleted: Bool = false

    // UI state
    @State private var showProjectPicker = false
    @State private var showDatePicker = false
    @State private var showPriorityMenu = false

    @FocusState private var nameFocused: Bool

    // Projects cache
    @State private var recentProjects: [String] = []

    private var canSave: Bool {
        !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    coreFieldsCard
                    labelsCard
                    priorityCard
                    metaCard
                    deleteOrCompleteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Edit Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { load() }
        }
        // Sheets / popovers
        .sheet(isPresented: $showProjectPicker) {
            ProjectPickerSheet(project: $project,
                               existing: recentProjects)
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCompleted.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill((isCompleted ? Color.green : Color.accentColor).opacity(0.15))
                            .frame(width: 54, height: 54)
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "tray")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(isCompleted ? .green : .accentColor)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Action name", text: $actionName)
                        .font(.system(size: 26, weight: .bold))
                        .focused($nameFocused)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(true)

                    if let priority {
                        HStack(spacing: 6) {
                            Label(priority.rawValue,
                                  systemImage: priority.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(priority.color)
                            if let dueDate {
                                DueBadge(due: dueDate, isCompleted: isCompleted)
                            }
                        }
                    } else if let dueDate {
                        DueBadge(due: dueDate, isCompleted: isCompleted)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Core Fields
    private var coreFieldsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                // Due Date
                HStack {
                    Label("Due Date", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation { toggleDate() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(dueDateLabel)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color(.tertiarySystemBackground))
                        )
                    }.buttonStyle(.plain)
                }

                if showDatePicker {
                    DatePicker("",
                               selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { new in dueDate = new }
                               ),
                               displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .transition(.opacity.combined(with: .scale))
                    HStack {
                        if dueDate != nil {
                            Button(role: .destructive) {
                                withAnimation { dueDate = nil }
                            } label: {
                                Label("Clear Date", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                    }
                }

                // Project
                VStack(alignment: .leading, spacing: 6) {
                    Label("Project", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        Text(project.isEmpty ? "None" : project)
                            .foregroundColor(project.isEmpty ? .secondary : .primary)
                        Spacer()
                        Button {
                            showProjectPicker = true
                        } label: {
                            Label("Select", systemImage: "chevron.right")
                                .labelStyle(.titleAndIcon)
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }

    // MARK: Labels
    private var labelsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Labels", systemImage: "tag")
                    .font(.subheadline.weight(.semibold))
                LabelsChipField(labels: $labels)
            }
        }
    }

    // MARK: Priority
    private var priorityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Priority", systemImage: "flag")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(ActionPriority.allCases) { p in
                        Button {
                            withAnimation { priority = (priority == p ? nil : p) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: p.symbol)
                                Text(p.rawValue)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(priority == p ? p.color.opacity(0.22) : Color(.tertiarySystemBackground))
                            )
                            .foregroundColor(priority == p ? p.color : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Metadata (Optional)
    private var metaCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Label("Metadata", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("Created")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(task.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .font(.caption)
                    }
                    GridRow {
                        Text("Domain")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(task.domain ?? "—")
                            .font(.caption)
                    }
                    GridRow {
                        Text("ID")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(task.id?.uuidString ?? "—")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }

    // MARK: Delete / Complete
    private var deleteOrCompleteCard: some View {
        card {
            VStack(spacing: 16) {
                Toggle(isOn: $isCompleted) {
                    Label("Completed", systemImage: "checkmark.circle")
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))

                Divider().padding(.vertical, 4)

                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete Action")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Helpers
    private func toggleDate() {
        if dueDate == nil { dueDate = Date() }
        withAnimation {
            showDatePicker.toggle()
        }
    }

    private var dueDateLabel: String {
        guard let dueDate else { return "None" }
        let cal = Calendar.current
        if cal.isDateInToday(dueDate) { return "Today" }
        if cal.isDateInTomorrow(dueDate) { return "Tomorrow" }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func load() {
        Task.prepareForEditing(task)
        actionName = task.actionName
        dueDate = task.dueDate
        project = task.project ?? ""
        labels = task.labelsArray
        priority = task.priority
        isCompleted = task.isCompleted

        fetchRecentProjects()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            nameFocused = actionName.isEmpty
        }
    }

    private func fetchRecentProjects() {
        let req: NSFetchRequest<Task> = Task.fetchRequest()
        req.fetchLimit = 40
        req.predicate = NSPredicate(format: "project != nil AND project != ''")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let results = try? context.fetch(req) {
            let names = results.compactMap { $0.project }
            let unique = Array(NSOrderedSet(array: names)) as? [String] ?? []
            recentProjects = unique.sorted { $0.lowercased() < $1.lowercased() }
        }
    }

    private func save() {
        guard canSave else { return }
        task.actionName = actionName.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = dueDate
        task.project = project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : project
        task.labelsArray = labels
        task.priority = priority
        task.isCompleted = isCompleted
        task.ensureCreatedAt()

        do {
            try context.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
        }
    }

    private func deleteAction() {
        context.delete(task)
        do {
            try context.save()
            dismiss()
        } catch {
            print("Delete error: \(error)")
        }
    }

    // Generic card style
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
}

// Reuse the DueBadge from earlier if you have it; otherwise:
private struct DueBadge: View {
    let due: Date
    let isCompleted: Bool
    var body: some View {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let dd = cal.startOfDay(for: due)
        let diff = cal.dateComponents([.day], from: base, to: dd).day ?? 0
        let (text, color): (String, Color) = {
            if isCompleted { return ("Done", .green) }
            if diff == 0 { return ("Today", .orange) }
            if diff == 1 { return ("Tomorrow", .yellow) }
            if diff < 0 { return ("\(abs(diff))d late", .red) }
            if diff <= 7 { return ("In \(diff)d", .blue) }
            return (due.formatted(.dateTime.month(.abbreviated).day()), .gray)
        }()
        return Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundColor(color)
    }
}