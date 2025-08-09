import SwiftUI

struct HomeView: View {
    var domain: DomainType

    var body: some View {
        NavigationView {
            TaskListView(domain: domain)
                .navigationTitle("\(domain.rawValue) Tasks")
        }
    }
}