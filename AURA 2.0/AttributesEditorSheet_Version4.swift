import SwiftUI
import CoreData

// Proxy used by the sheet to push raw edits back into TaskDetailView state
struct TDPrimaryAttributeProxy {
    var title: Binding<String>
    var project: Binding<String>
    var notes: Binding<String>
    var dueDate: Binding<Date>
    var domain: Binding<String?>
    var isCompleted: Binding<Bool>
    var statusRaw: Binding<String>
}

struct TDAttributesEditorSheet: View {
    @ObservedObject var task: Task
    let primaryState: TDPrimaryAttributeProxy
    var onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var workingValues: [String: Any] = [:]
    @State private var originalValues: [String: Any] = [:]

    @State private var showOnlyChanged = false
    @State private var hideStandard = false
    @State private var showEmpty = true

    private let standardKeys: Set<String> = [
        "title","project","notes","dueDate","status","domain","createdAt","isCompleted"
    ]

    private struct Row: Identifiable {
        let id = UUID()
        let name: String
        let type: NSAttributeType
        let value: Any?
        let edited: Bool
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters
                Divider()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(rows) { row in
                            rowView(row)
                                .padding(.horizontal, 16)
                        }
                        if rows.isEmpty {
                            Text("No attributes match filters.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.vertical, 16)
                }
                footer
                    .padding(.top, 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .background(TDBackgroundGradient().ignoresSafeArea())
            .navigationTitle("Attributes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        apply()
                        dismiss()
                    }
                }
            }
            .onAppear { load() }
        }
    }

    // MARK: Filters
    private var filters: some View {
        HStack(spacing: 12) {
            toggle("Changed", $showOnlyChanged)
            toggle("Hide Std", $hideStandard)
            toggle("Show Empty", $showEmpty)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func toggle(_ label: String, _ binding: Binding<Bool>) -> some View {
        Button {
            withAnimation { binding.wrappedValue.toggle() }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(binding.wrappedValue ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemBackground))
                )
                .foregroundColor(binding.wrappedValue ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Rows
    private var rows: [Row] {
        let attrs = task.entity.attributesByName
        return attrs.keys.sorted().compactMap { key in
            if hideStandard && standardKeys.contains(key) { return nil }
            let desc = attrs[key]!
            let cur = workingValues[key]
            let orig = originalValues[key]
            let edited = !equalAny(cur, orig)
            if showOnlyChanged && !edited { return nil }
            if !showEmpty && (cur == nil || (cur as? String)?.isEmpty == true) { return nil }
            return Row(name: key, type: desc.attributeType, value: cur, edited: edited)
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name)
                    .font(.system(size: 13, weight: .semibold))
                if row.edited {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                }
                Spacer()
                Text(typeLabel(row.type))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.tertiarySystemBackground)))
            }
            editor(for: row)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: Editor Controls
    @ViewBuilder
    private func editor(for row: Row) -> some View {
        switch row.type {
        case .stringAttributeType:
            TextField("Value", text: Binding(
                get: { (workingValues[row.name] as? String) ?? "" },
                set: { workingValues[row.name] = $0 }
            ))
            .textFieldStyle(.roundedBorder)

        case .booleanAttributeType:
            Toggle("Value", isOn: Binding(
                get: { (workingValues[row.name] as? Bool) ?? false },
                set: { workingValues[row.name] = $0 }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

        case .dateAttributeType:
            DatePicker("",
                       selection: Binding(
                        get: { (workingValues[row.name] as? Date) ?? Date() },
                        set: { workingValues[row.name] = $0 }),
                       displayedComponents: [.date])
                .labelsHidden()

        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            IntegerField(value: Binding(
                get: {
                    if let n = workingValues[row.name] as? NSNumber { return n.int64Value }
                    if let i = workingValues[row.name] as? Int { return Int64(i) }
                    return 0
                },
                set: { workingValues[row.name] = NSNumber(value: $0) }
            ))

        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            DecimalField(value: Binding(
                get: {
                    if let n = workingValues[row.name] as? NSNumber { return n.doubleValue }
                    return 0
                },
                set: { workingValues[row.name] = NSNumber(value: $0) }
            ))

        default:
            Text(preview(row.value))
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !(row.type == .stringAttributeType) {
            Text(preview(row.value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Footer
    private var footer: some View {
        HStack {
            Button {
                workingValues = originalValues
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .disabled(!hasChanges)
            Spacer()
            Button {
                apply()
                onApply()
            } label: {
                Label("Apply", systemImage: "checkmark.seal")
                    .font(.headline)
            }
            .disabled(!hasChanges)
        }
    }

    // MARK: Load / Apply
    private var hasChanges: Bool {
        workingValues.contains { key, value in
            !equalAny(value, originalValues[key])
        }
    }

    private func load() {
        let attrs = task.entity.attributesByName
        var dict: [String: Any] = [:]
        for (k, _) in attrs {
            dict[k] = task.value(forKey: k) ?? nil
        }
        workingValues = dict
        originalValues = dict
    }

    private func apply() {
        let attrs = task.entity.attributesByName
        var needsStatusRecalc = false
        for (k, _) in attrs {
            let newVal = workingValues[k]
            let oldVal = task.value(forKey: k)
            if !equalAny(newVal, oldVal) {
                if newVal is NSNull { task.setValue(nil, forKey: k) }
                else { task.setValue(newVal, forKey: k) }
                if ["dueDate","status","isCompleted"].contains(k) { needsStatusRecalc = true }
                syncPrimary(key: k, value: newVal)
            }
        }
        if needsStatusRecalc {
            task.autoUpdateStatus()
            syncPrimaryFromTask()
        }
        try? context.save()
        load()
    }

    // MARK: Sync helpers
    private func syncPrimary(key: String, value: Any?) {
        switch key {
        case "title": primaryState.title.wrappedValue = (value as? String) ?? ""
        case "project": primaryState.project.wrappedValue = (value as? String) ?? ""
        case "notes": primaryState.notes.wrappedValue = (value as? String) ?? ""
        case "dueDate": if let d = value as? Date { primaryState.dueDate.wrappedValue = d }
        case "domain":
            if let s = value as? String { primaryState.domain.wrappedValue = s } else { primaryState.domain.wrappedValue = nil }
        case "isCompleted": primaryState.isCompleted.wrappedValue = (value as? Bool) ?? false
        case "status": if let s = value as? String { primaryState.statusRaw.wrappedValue = s }
        default: break
        }
    }

    private func syncPrimaryFromTask() {
        primaryState.title.wrappedValue = task.title ?? ""
        primaryState.project.wrappedValue = task.project ?? ""
        primaryState.notes.wrappedValue = task.notes ?? ""
        primaryState.dueDate.wrappedValue = task.dueDate ?? Date()
        primaryState.domain.wrappedValue = task.domain
        primaryState.isCompleted.wrappedValue = task.isCompleted
        primaryState.statusRaw.wrappedValue = task.status ?? TaskStatus.inbox.rawValue
    }

    // MARK: Utilities
    private func typeLabel(_ t: NSAttributeType) -> String {
        switch t {
        case .stringAttributeType: return "String"
        case .booleanAttributeType: return "Bool"
        case .dateAttributeType: return "Date"
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType: return "Int"
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType: return "Number"
        default: return "Other"
        }
    }

    private func preview(_ v: Any?) -> String {
        guard let v else { return "nil" }
        if let d = v as? Date { return d.formatted(date: .abbreviated, time: .shortened) }
        if let n = v as? NSNumber { return n.stringValue }
        return String(describing: v)
    }

    private func equalAny(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (l as String, r as String): return l == r
        case let (l as Bool, r as Bool): return l == r
        case let (l as Date, r as Date): return abs(l.timeIntervalSince1970 - r.timeIntervalSince1970) < 0.5
        case let (l as NSNumber, r as NSNumber): return l == r
        default: return false
        }
    }
}

// MARK: - Numeric Editors

private struct IntegerField: View {
    @Binding var value: Int64
    @State private var text = ""
    var body: some View {
        TextField("Int", text: Binding(
            get: { text.isEmpty ? String(value) : text },
            set: {
                text = $0
                if let i = Int64($0) { value = i }
            }
        ))
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numberPad)
    }
}

private struct DecimalField: View {
    @Binding var value: Double
    @State private var text = ""
    var body: some View {
        TextField("Number", text: Binding(
            get: { text.isEmpty ? String(value) : text },
            set: {
                text = $0
                if let d = Double($0.replacingOccurrences(of: ",", with: ".")) {
                    value = d
                }
            }
        ))
        .textFieldStyle(.roundedBorder)
        .keyboardType(.decimalPad)
    }
}
