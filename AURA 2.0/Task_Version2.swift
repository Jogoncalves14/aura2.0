import Foundation
import CoreData

@objc(Task)
public class Task: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var dueDate: Date?
    @NSManaged public var labels: [String]?
    @NSManaged public var priority: Int16
    @NSManaged public var project: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var reminderTime: Date?
    @NSManaged public var status: String?
    @NSManaged public var domain: String?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }
}
