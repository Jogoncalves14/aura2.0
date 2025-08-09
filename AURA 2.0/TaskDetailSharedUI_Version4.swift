import SwiftUI

// MARK: - Basic reusable components (prefixed TD to avoid collisions)

struct TDBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct TDSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
    }
}

struct TDCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
    }
}

struct TDMetaChip: View {
    let icon: String
    let text: String
    let tone: Color
    var active: Bool = false
    var secondary: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let s = secondary {
                        Text(s)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, secondary == nil ? 10 : 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? tone.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .foregroundColor(active ? tone : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TDStatusPill: View {
    let status: TaskStatus
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: status.symbol)
                Text(status.rawValue)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? status.tint.opacity(0.2) : Color(.tertiarySystemBackground))
            )
            .foregroundColor(selected ? status.tint : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TDDomainCapsule: View {
    let domain: DomainType?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: domain?.icon ?? "slash.circle")
                Text(domain?.rawValue ?? "None")
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? Color.purple.opacity(0.2) : Color(.tertiarySystemBackground))
            )
            .foregroundColor(selected ? .purple : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TDFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content
    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }
    var body: some View {
        GeometryReader { geo in generate(in: geo) }
            .frame(minHeight: 0)
    }
    private func generate(in geo: GeometryProxy) -> some View {
        var w: CGFloat = 0
        var h: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content
                .padding(.trailing, spacing)
                .alignmentGuide(.leading) { d in
                    if w + d.width > geo.size.width {
                        w = 0; h += d.height + lineSpacing
                    }
                    let result = w
                    w += d.width + spacing
                    return -result
                }
                .alignmentGuide(.top) { _ in
                    let result = h
                    return -result
                }
        }
    }
}

struct TDAdaptiveTitleEditor: View {
    @Binding var text: String
    @State private var height: CGFloat = 48
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 26, weight: .bold))
                .frame(height: height)
                .scrollContentBackground(.hidden)
                .background(
                    Color.clear
                        .onAppear { recalc() }
                        .onChange(of: text) { _ in recalc() }
                )
            if text.isEmpty {
                Text("Task title")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
                    .padding(.leading, 5)
            }
        }
    }
    private func recalc() {
        let lines = max(1, text.split(separator: "\n").count + (text.hasSuffix("\n") ? 1 : 0))
        let lineHeight: CGFloat = 34
        height = min(max(48, CGFloat(lines) * lineHeight), 140)
    }
}

struct TDQuickDateButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(.tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

struct TDEditorSheetWrapper<Content: View>: View {
    let title: String
    let tint: Color
    let content: Content
    @Environment(\.dismiss) private var dismiss
    init(title: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title; self.tint = tint; self.content = content()
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .padding(20)
            }
            .background(TDBackgroundGradient().ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(tint)
    }
}

struct TDStatusSummaryLine: View {
    let status: TaskStatus
    let isCompleted: Bool
    let dueDate: Date
    var body: some View {
        HStack(spacing: 8) {
            Label(isCompleted ? "Completed" : status.rawValue,
                  systemImage: isCompleted ? TaskStatus.completed.symbol : status.symbol)
                .font(.caption.weight(.semibold))
                .foregroundColor(status.tint)
            TDDueBadge(due: dueDate, isCompleted: isCompleted)
        }
    }
}

struct TDDueBadge: View {
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
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundColor(color)
    }
}
