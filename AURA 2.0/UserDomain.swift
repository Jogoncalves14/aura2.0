import Foundation

class UserDomain: ObservableObject {
    @Published var selectedDomain: DomainType? = nil
}
