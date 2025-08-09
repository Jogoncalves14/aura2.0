import SwiftUI

struct LabelsChipField: View {
    @Binding var labels: [String]
    @State private var newLabel: String = ""
    var suggested: [String] = ["Home","Work","Morning","Afternoon"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(labels, id: \.self) { label in
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(0.6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.blue.opacity(0.15))
                    )
                    .foregroundColor(.blue)
                    .onTapGesture {
                        withAnimation {
                            labels.removeAll { $0 == label }
                        }
                    }
                }

                // Input pill
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                    TextField("Add label", text: $newLabel, onCommit: commitLabel)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .frame(minWidth: 60)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().strokeBorder(Color.accentColor.opacity(0.3))
                )
            }

            if !suggested.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggested.filter { !labels.contains($0) }, id: \.self) { sug in
                            Button {
                                withAnimation {
                                    labels.append(sug)
                                }
                            } label: {
                                Text("#\(sug)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color(.tertiarySystemBackground))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func commitLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            if !labels.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                labels.append(trimmed)
            }
        }
        newLabel = ""
    }
}

// Lightweight flow layout (namespace-locally reused)
struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content
    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }
    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }.frame(minHeight: 0)
    }
    private func generate(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content
                .padding(.trailing, spacing)
                .alignmentGuide(.leading) { d in
                    if width + d.width > geo.size.width {
                        width = 0
                        height += d.height + lineSpacing
                    }
                    let result = width
                    width += d.width + spacing
                    return -result
                }
                .alignmentGuide(.top) { _ in
                    let result = height
                    return -result
                }
        }
    }
}