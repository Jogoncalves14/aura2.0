import SwiftUI

struct TaskListView: View {
    var domain: DomainType
    @Environment(\.managedObjectContext) private var viewContext

    var fetchRequest: FetchRequest<Task>
    var tasks: FetchedResults<Task> { fetchRequest.wrappedValue }

    init(domain: DomainType) {
        fetchRequest = FetchRequest<Task>(
            entity: Task.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)],
            predicate: NSPredicate(format: "domain == %@", domain.rawValue)
        )
        self.domain = domain
    }

    @State private var showAddTask = false

    var body: some View {
        List {
            ForEach(tasks) { task in
                Text(task.title)
            }
        }
        .toolbar {
            Button(action: { showAddTask = true }) {
                Label("Add Task", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(domain: domain)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}
