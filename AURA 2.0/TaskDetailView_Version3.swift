import SwiftUI
import CoreData

struct TaskDetailView: View {
    @ObservedObject var task: Task
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Primary state
    @State private var title = ""
    @State private var project = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var domain: DomainType? = nil
    @State private var isCompleted = false
    @State private var currentStatus: TaskStatus = .inbox

    @State private var recentProjects: [String] = []

    // Sheet toggles (if you kept the sheets – you can remove if not using)
    @State private var showProjectSheet = false
    @State private var showDueSheet = false
    @State private var showStatusSheet = false
    @State private var showDomainSheet = false
    @State private var showAttributesSheet = false   // Only used if you still have the separate sheet

    @State private var saving = false
    @State private var showDeleteConfirm = false
    @FocusState private var titleFocused: Bool

    private struct Snapshot {
        let title: String
        let project: String
        let notes: String
        let dueDate: Date
        let domain: String?
        let isCompleted: Bool
        let status: String?
        let rawAttributes: [String: Any?]
    }
    @State private var original: Snapshot?

    // MARK: - Dynamic Attribute Editing State
    // Working copies for ALL attributes (including primary) so we can diff & show.
    @State private var attributeWorking: [String: Any?] = [:]
    @State private var attributeOriginal: [String: Any?] = [:]
    @State private var showAttributesInline = false  // disclosure group state

    // CONFIG: Adjust these to change behavior
    private let startExpanded = false
    private let enablePrimaryAttributeEditing = false
    private let showPrimaryDuplicates = true // Set to false to hide title/notes/etc in list

    // Derived sets
    private var primaryAttributeKeys: Set<String> {
        ["title","project","notes","dueDate","status","domain","isCompleted","createdAt"]
    }

    // MARK: Body
    var body: some View {
        ZStack {
            TDBackgroundGradient()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    chipRow
                    notesCard
                    createdCard
                    inlineAttributesSection
                    deleteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbar }
        .onAppear {
            load()
            showAttributesInline = startExpanded
        }
        .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Task", role: .destructive) { deleteTask() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: dueDate) { _ in handleDueDateChange() }
        .onChange(of: isCompleted) { _ in handleCompletionToggle() }

        // If you still use sheets, keep these:
        .sheet(isPresented: $showProjectSheet) { ProjectSheet }
        .sheet(isPresented: $showDueSheet) { DueSheet }
        .sheet(isPresented: $showStatusSheet) { StatusSheet }
        .sheet(isPresented: $showDomainSheet) { DomainSheet }
    }

    // MARK: Toolbar
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { cancel() } }
        ToolbarItem(placement: .principal) { Text("Edit Task").font(.headline) }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                save()
            } label: {
                if saving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
            }.disabled(!canSave)
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCompleted.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(currentStatus.tint.opacity(0.15))
                            .frame(width: 54, height: 54)
                        Image(systemName: isCompleted ? TaskStatus.completed.symbol : currentStatus.symbol)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(currentStatus.tint)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    TDAdaptiveTitleEditor(text: $title)
                        .focused($titleFocused)
                    TDStatusSummaryLine(status: currentStatus, isCompleted: isCompleted, dueDate: dueDate)
                }
                Spacer()
            }
        }
    }

    // MARK: Chips Row (if you want a minimal set; adjust / remove as desired)
    private var chipRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            TDFlowLayout(spacing: 10, lineSpacing: 12) {
                TDMetaChip(icon: "folder",
                           text: project.isEmpty ? "Project" : project,
                           tone: .blue,
                           active: !project.isEmpty) { showProjectSheet = true }

                TDMetaChip(icon: "calendar",
                           text: dueChipLabel,
                           tone: .orange,
                           active: true,
                           secondary: dueRelativeSummary) { showDueSheet = true }

                TDMetaChip(icon: currentStatus.symbol,
                           text: currentStatus.rawValue,
                           tone: currentStatus.tint,
                           active: true) { showStatusSheet = true }

                TDMetaChip(icon: domain?.icon ?? "globe",
                           text: domain?.rawValue ?? "Domain",
                           tone: .purple,
                           active: domain != nil) { showDomainSheet = true }
            }

            Text("Tap chips to edit details")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: Notes
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TDSectionLabel("Notes")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                if notes.isEmpty {
                    Text("Add notes…")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
            }
            .modifier(TDCardSurface())
        }
    }

    // MARK: Created Card
    private var createdCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Created").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Text(task.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    .font(.footnote)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Due").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .modifier(TDCardSurface())
    }

    // MARK: Inline Attributes Section
    private var inlineAttributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showAttributesInline) {
                attributesList
                    .padding(.top, 6)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.adjustable")
                    Text("Attributes")
                        .font(.subheadline.weight(.semibold))
                    if hasAttributeChanges {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .transition(.scale)
                    }
                    Spacer()
                    Text(showAttributesInline ? "Hide" : "Show")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showAttributesInline)
        }
        .padding(.vertical, 8)
    }

    private var attributesList: some View {
        VStack(spacing: 10) {
            ForEach(sortedAttributeKeys, id: \.self) { key in
                attributeRow(for: key)
            }
            if sortedAttributeKeys.isEmpty {
                Text("No attributes found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private var sortedAttributeKeys: [String] {
        guard let entity = task.entity as NSEntityDescription? else { return [] }
        return entity.attributesByName.keys
            .filter { showPrimaryDuplicates || !primaryAttributeKeys.contains($0) }
            .sorted()
    }

    private var hasAttributeChanges: Bool {
        attributeWorking.contains { (key, val) in
            let orig = attributeOriginal[key] ?? nil
            return !attributeValuesEqual(val, orig)
        }
    }

    // MARK: Attribute Row
    @ViewBuilder
    private func attributeRow(for key: String) -> some View {
        let value = attributeWorking[key] ?? nil
        let originalValue = attributeOriginal[key] ?? nil
        let edited = !attributeValuesEqual(value, originalValue)

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key)
                        .font(.system(size: 13, weight: .semibold))
                    if edited {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .transition(.scale)
                    }
                }
                Text(attributeTypeLabel(key: key))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            attributeEditor(for: key, value: value)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }

    private func attributeTypeLabel(key: String) -> String {
        guard let attr = task.entity.attributesByName[key] else { return "?" }
        switch attr.attributeType {
        case .stringAttributeType: return "String"
        case .dateAttributeType: return "Date"
        case .booleanAttributeType: return "Bool"
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType: return "Int"
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType: return "Number"
        case .UUIDAttributeType: return "UUID"
        case .binaryDataAttributeType: return "Data"
        case .transformableAttributeType: return "Transformable"
        default: return "Other"
        }
    }

    // MARK: Editors
    @ViewBuilder
    private func attributeEditor(for key: String, value: Any?) -> some View {
        let attr = task.entity.attributesByName[key]
        let isPrimary = primaryAttributeKeys.contains(key)
        let allowEdit = enablePrimaryAttributeEditing || !isPrimary

        switch attr?.attributeType {
        case .stringAttributeType:
            if allowEdit {
                TextField("Text", text: Binding(
                    get: { (attributeWorking[key] as? String) ?? "" },
                    set: { new in setWorkingValue(key, new) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            } else {
                Text((value as? String) ?? "nil")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 180, alignment: .trailing)
            }

        case .booleanAttributeType:
            Toggle("", isOn: Binding(
                get: { (attributeWorking[key] as? Bool) ?? false },
                set: { new in setWorkingValue(key, new) }
            ))
            .labelsHidden()
            .disabled(!allowEdit)

        case .dateAttributeType:
            if allowEdit {
                DatePicker("",
                           selection: Binding(
                               get: { (attributeWorking[key] as? Date) ?? Date() },
                               set: { new in setWorkingValue(key, new) }),
                           displayedComponents: [.date])
                .labelsHidden()
            } else {
                if let d = value as? Date {
                    Text(d.formatted(date: .abbreviated, time: .omitted))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("nil").font(.footnote).foregroundColor(.secondary)
                }
            }

        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            if allowEdit {
                TextField("Int", text: Binding(
                    get: {
                        if let n = attributeWorking[key] as? NSNumber { return n.stringValue }
                        if let i = attributeWorking[key] as? Int { return String(i) }
                        return ""
                    },
                    set: { new in
                        if let i = Int64(new) { setWorkingValue(key, NSNumber(value: i)) }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(maxWidth: 100)
            } else {
                Text(intDisplay(value))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            if allowEdit {
                TextField("Num", text: Binding(
                    get: {
                        if let n = attributeWorking[key] as? NSNumber { return n.stringValue }
                        return ""
                    },
                    set: { new in
                        if let d = Double(new.replacingOccurrences(of: ",", with: ".")) {
                            setWorkingValue(key, NSNumber(value: d))
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 110)
            } else {
                Text(numDisplay(value))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

        case .UUIDAttributeType:
            if allowEdit {
                TextField("UUID", text: Binding(
                    get: {
                        if let u = attributeWorking[key] as? UUID { return u.uuidString }
                        return ""
                    },
                    set: { new in
                        if let u = UUID(uuidString: new) {
                            setWorkingValue(key, u)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .frame(maxWidth: 210)
            } else {
                Text((value as? UUID)?.uuidString ?? "nil")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 210, alignment: .trailing)
            }

        default:
            Text(readOnlyDisplay(value))
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: 210, alignment: .trailing)
        }
    }

    private func setWorkingValue(_ key: String, _ newValue: Any?) {
        attributeWorking[key] = newValue
        // If editing a primary attribute and editing is enabled, sync primary state
        if enablePrimaryAttributeEditing {
            switch key {
            case "title": title = (newValue as? String) ?? ""
            case "project": project = (newValue as? String) ?? ""
            case "notes": notes = (newValue as? String) ?? ""
            case "dueDate": if let d = newValue as? Date { dueDate = d }
            case "domain":
                if let s = newValue as? String { domain = DomainType(rawValue: s) } else { domain = nil }
            case "isCompleted":
                isCompleted = (newValue as? Bool) ?? false
                handleCompletionToggle()
            case "status":
                if let sRaw = newValue as? String, let s = TaskStatus(rawValue: sRaw) {
                    currentStatus = s
                    isCompleted = (s == .completed)
                }
            default: break
            }
        }
    }

    // MARK: Formatting helpers
    private func readOnlyDisplay(_ v: Any?) -> String {
        guard let v else { return "nil" }
        if let d = v as? Date { return d.formatted(date: .abbreviated, time: .shortened) }
        if let n = v as? NSNumber { return n.stringValue }
        if let uuid = v as? UUID { return uuid.uuidString }
        if let data = v as? Data { return "Data(\(data.count))" }
        return String(describing: v)
    }
    private func intDisplay(_ v: Any?) -> String {
        guard let v else { return "nil" }
        if let n = v as? NSNumber { return n.stringValue }
        if let i = v as? Int { return String(i) }
        return String(describing: v)
    }
    private func numDisplay(_ v: Any?) -> String {
        guard let v else { return "nil" }
        if let n = v as? NSNumber { return n.stringValue }
        return String(describing: v)
    }

    private func attributeValuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (l as String, r as String): return l == r
        case let (l as Bool, r as Bool): return l == r
        case let (l as Date, r as Date): return abs(l.timeIntervalSince1970 - r.timeIntervalSince1970) < 0.5
        case let (l as NSNumber, r as NSNumber): return l == r
        case let (l as UUID, r as UUID): return l == r
        default: return false
        }
    }

    // MARK: Delete Card
    private var deleteCard: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("Delete Task")
                Spacer()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.red)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.red.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Derived Strings
    private var dueChipLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(dueDate) { return "Today" }
        if cal.isDateInTomorrow(dueDate) { return "Tomorrow" }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }
    private var dueRelativeSummary: String {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: dueDate)
        let diff = cal.dateComponents([.day], from: base, to: target).day ?? 0
        if isCompleted { return "Done" }
        if diff == 0 { return "Due today" }
        if diff == 1 { return "In 1 day" }
        if diff < 0 {
            let p = abs(diff)
            return p == 1 ? "1 day late" : "\(p)d late"
        }
        if diff <= 7 { return "In \(diff)d" }
        return target.formatted(.dateTime.month(.abbreviated).day())
    }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Logic
    private func handleDueDateChange() {
        if isCompleted { currentStatus = .completed; return }
        if currentStatus == .inProgress || currentStatus == .needsReview {
            if dueDate < Calendar.current.startOfDay(for: Date()) { currentStatus = .overdue }
            return
        }
        recalcStatusPreview()
    }
    private func handleCompletionToggle() {
        if isCompleted { currentStatus = .completed } else { recalcStatusPreview() }
    }
    private func recalcStatusPreview() {
        let scratch = Task(context: context)
        scratch.status = currentStatus.rawValue
        scratch.isCompleted = isCompleted
        scratch.dueDate = dueDate
        scratch.autoUpdateStatus()
        if let raw = scratch.status, let mapped = TaskStatus(rawValue: raw) {
            currentStatus = mapped
        }
    }

    // MARK: Load
    private func load() {
        title = task.title ?? ""
        project = task.project ?? ""
        notes = task.notes ?? ""
        dueDate = task.dueDate ?? Date()
        domain = DomainType(rawValue: task.domain ?? "")
        isCompleted = task.isCompleted
        currentStatus = TaskStatus(rawValue: task.status ?? TaskStatus.inbox.rawValue) ?? .inbox

        // Capture originals
        var rawAttrs: [String: Any?] = [:]
        if let entity = task.entity as NSEntityDescription? {
            for key in entity.attributesByName.keys {
                rawAttrs[key] = task.value(forKey: key)
            }
        }
        attributeWorking = rawAttrs
        attributeOriginal = rawAttrs

        original = Snapshot(
            title: title,
            project: project,
            notes: notes,
            dueDate: dueDate,
            domain: task.domain,
            isCompleted: isCompleted,
            status: task.status,
            rawAttributes: rawAttrs
        )

        if task.createdAt == nil {
            task.createdAt = Date()
            try? context.save()
        }

        fetchRecentProjects()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { titleFocused = true }
    }

    private func fetchRecentProjects() {
        let req: NSFetchRequest<Task> = Task.fetchRequest()
        req.fetchLimit = 40
        req.predicate = NSPredicate(format: "project != nil AND project != ''")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if let results = try? context.fetch(req) {
            let names = results.compactMap { $0.project }
            let distinct = Array(NSOrderedSet(array: names)) as? [String] ?? []
            recentProjects = Array(distinct.prefix(8))
        }
    }

    // MARK: Save
    private func save() {
        guard canSave else { return }
        saving = true

        // Primary fields
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.project = project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : project
        task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        task.dueDate = dueDate
        task.domain = domain?.rawValue
        task.isCompleted = isCompleted
        task.status = currentStatus.rawValue

        // Apply dynamic attribute edits (non-primary or all if editing enabled)
        if let entity = task.entity as NSEntityDescription? {
            for key in entity.attributesByName.keys {
                guard attributeWorking.keys.contains(key) else { continue }
                let val = attributeWorking[key] ?? nil
                // Skip primary if we already assigned above unless we allow editing
                if primaryAttributeKeys.contains(key) && !enablePrimaryAttributeEditing { continue }
                if val is NSNull {
                    task.setValue(nil, forKey: key)
                } else {
                    task.setValue(val, forKey: key)
                }
            }
        }

        task.autoUpdateStatus()
        if task.createdAt == nil { task.createdAt = Date() }

        do {
            try context.save()
            dismiss()
        } catch {
            print("Save error: \(error)")
            saving = false
        }
    }

    // MARK: Cancel / Delete
    private func cancel() {
        if let s = original {
            task.title = s.title
            task.project = s.project.isEmpty ? nil : s.project
            task.notes = s.notes.isEmpty ? nil : s.notes
            task.dueDate = s.dueDate
            task.domain = s.domain
            task.isCompleted = s.isCompleted
            task.status = s.status

            // revert raw attrs
            for (k, v) in s.rawAttributes {
                task.setValue(v is NSNull ? nil : v, forKey: k)
            }
        }
        dismiss()
    }

    private func deleteTask() {
        context.delete(task)
        do { try context.save(); dismiss() }
        catch { print("Delete error: \(error)") }
    }
}

// MARK: - Sheet Content (if still using; otherwise you can remove)
private extension TaskDetailView {
    var ProjectSheet: some View {
        TDEditorSheetWrapper(title: "Project", tint: .blue) {
            VStack(spacing: 16) {
                TextField("Project name", text: $project)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                if !recentProjects.isEmpty {
                    TDFlowLayout {
                        ForEach(recentProjects, id: \.self) { name in
                            Button {
                                project = name
                            } label: {
                                Text(name)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(project == name ? Color.blue.opacity(0.25) : Color(.tertiarySystemBackground))
                                    )
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !project.isEmpty {
                    Button(role: .destructive) { project = "" } label: {
                        Label("Clear Project", systemImage: "xmark.circle")
                    }
                }
            }
        }
    }

    var DueSheet: some View {
        TDEditorSheetWrapper(title: "Due Date", tint: .orange) {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker("Select Date", selection: $dueDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                HStack(spacing: 8) {
                    TDQuickDateButton("Today") { dueDate = Date() }
                    TDQuickDateButton("Tomorrow") {
                        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }
                    TDQuickDateButton("Next Week") {
                        dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                    }
                }
            }
        }
    }

    var StatusSheet: some View {
        TDEditorSheetWrapper(title: "Status", tint: currentStatus.tint) {
            TDFlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(TaskStatus.allCases, id: \.rawValue) { s in
                    TDStatusPill(status: s, selected: currentStatus == s) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStatus = s
                            isCompleted = (s == .completed)
                        }
                    }
                }
            }
            Divider().padding(.vertical, 4)
            Button {
                recalcStatusPreview()
            } label: {
                Label("Recalculate Automatically", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    var DomainSheet: some View {
        TDEditorSheetWrapper(title: "Domain", tint: .purple) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    TDDomainCapsule(domain: nil, selected: domain == nil) {
                        withAnimation { domain = nil }
                    }
                    ForEach(DomainType.allCases) { d in
                        TDDomainCapsule(domain: d, selected: domain == d) {
                            withAnimation { domain = d }
                        }
                    }
                }
            }
        }
    }
}
