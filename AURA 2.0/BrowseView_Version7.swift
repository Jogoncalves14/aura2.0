import SwiftUI

struct BrowseView: View {
    @FetchRequest(
        entity: Task.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", TaskStatus.completed.rawValue)
    ) var completedTasks: FetchedResults<Task>

    var body: some View {
        List {
            ForEach(completedTasks) { task in
                Text(task.title)
            }
        }
        .navigationTitle("Browse")
    }
}