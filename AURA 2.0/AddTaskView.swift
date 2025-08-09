import SwiftUI

struct AddTaskView: View {
    var domain: DomainType
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title: String = ""
    @State private var project: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextField("Project", text: $project)
                }
                Button("Save") {
                    let newTask = Task(context: viewContext)
                    newTask.title = title
                    newTask.project = project
                    newTask.domain = domain.rawValue
                    newTask.createdAt = Date()
                    newTask.status = TaskStatus.inbox.rawValue // Default status
                    try? viewContext.save()
                }
                .disabled(title.isEmpty)
            }
            .navigationTitle("Add Task")
        }
    }
}
