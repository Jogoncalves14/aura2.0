import SwiftUI

struct InboxView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: Task.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", TaskStatus.inbox.rawValue)
    ) var inboxTasks: FetchedResults<Task>

    var body: some View {
        List {
            ForEach(inboxTasks) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    Text(task.title)
                }
            }
        }
        .navigationTitle("Inbox")
    }
}