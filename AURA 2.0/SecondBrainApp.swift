import SwiftUI

@main
struct SecondBrainApp: App {
    @StateObject var userDomain = UserDomain()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userDomain)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
