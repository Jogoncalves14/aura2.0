import SwiftUI
import CoreData

struct ProjectPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: String
    @State private var newProject: String = ""
    var existing: [String]

    var body: some View {
        NavigationStack {
            Form {
                if existing.isEmpty {
                    Section("No Projects Yet") {
                        Text("Create your first project below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Select Project") {
                        ForEach(existing, id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                if project == name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                project = name
                            }
                        }
                    }
                }
                Section("New Project") {
                    HStack {
                        TextField("Project name", text: $newProject)
                            .textInputAutocapitalization(.words)
                        Button("Add") {
                            commitNewProject()
                        }.disabled(newProject.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !project.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            project = ""
                        } label: {
                            Label("Clear Selected Project", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Project")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func commitNewProject() {
        let trimmed = newProject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project = trimmed
        newProject = ""
    }
}