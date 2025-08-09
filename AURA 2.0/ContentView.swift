import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userDomain: UserDomain

    var body: some View {
        Group {
            if let _ = userDomain.selectedDomain {
                MainView() // <-- No argument passed
            } else {
                DomainPickerView()
            }
        }
    }
}
