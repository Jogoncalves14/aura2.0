import SwiftUI
import CoreData

struct InboxTrayListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var userDomain: UserDomain

    @Binding var isPresented: Bool
    let selectedDomain: DomainType?

    @FetchRequest private var tasks: FetchedResults<Task>
    @State private var taskForEditing: Task?

    init(isPresented: Binding<Bool>, selectedDomain: DomainType?) {
        self._isPresented = isPresented
        self.selectedDomain = selectedDomain

        var predicates: [NSPredicate] = [
            NSPredicate(format: "status == %@", TaskStatus.inbox.rawValue)
        ]
        if let d = selectedDomain {
            predicates.append(NSPredicate(format: "domain == %@", d.rawValue))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        _tasks = FetchRequest(
            entity: Task.entity(),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
        )
        .frame(width: 300, height: 500)
        .sheet(item: $taskForEditing) { task in
            TaskDetailView(task: task)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(userDomain)
        }
        .onAppear { backfillCreatedAtIfNeeded() }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            Text("Inbox")
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: Content
    @ViewBuilder
    private var content: some View {
        if tasks.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(tasks.prefix(50)) { task in
                        Button {
                            taskForEditing = task
                        } label: {
                            taskRow(task)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("Nothing in your Inbox")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func taskRow(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title ?? "Untitled")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            HStack(spacing: 10) {
                if let project = task.project, !project.isEmpty {
                    Label(project, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .labelStyle(CondensedIconLabelStyle())
                }
                if let date = task.dueDate {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .labelStyle(CondensedIconLabelStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.clear)
        )
        .hoverEffect(.highlight)
    }

    // Backfill createdAt if older tasks lack it (optional)
    private func backfillCreatedAtIfNeeded() {
        var needsSave = false
        for t in tasks where t.createdAt == nil {
            t.createdAt = Date()
            needsSave = true
        }
        if needsSave { try? viewContext.save() }
    }
}

// MARK: - Condensed Label Style
fileprivate struct CondensedIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
