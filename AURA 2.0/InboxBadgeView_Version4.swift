import SwiftUI
import CoreData
import UIKit   // For haptics

struct InboxBadgeView: View {
    let domain: DomainType?
    let trayOpen: Bool   // When true, badge is hidden entirely.

    // Core Data fetch
    private var fetchRequest: FetchRequest<Task>
    private var tasks: FetchedResults<Task> { fetchRequest.wrappedValue }

    // Animation / state
    @State private var lastCount: Int = 0
    @State private var pulse: Bool = false
    @State private var hapticReady = true

    init(domain: DomainType?, trayOpen: Bool) {
        self.domain = domain
        self.trayOpen = trayOpen

        var predicates: [NSPredicate] = [
            NSPredicate(format: "status == %@", TaskStatus.inbox.rawValue)
        ]
        if let domain {
            predicates.append(NSPredicate(format: "domain == %@", domain.rawValue))
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        self.fetchRequest = FetchRequest<Task>(
            entity: Task.entity(),
            sortDescriptors: [],
            predicate: predicate,
            animation: .default
        )
    }

    // MARK: - View
    var body: some View {
        let count = tasks.count
        Group {
            if !trayOpen, count > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: badgeDiameter, height: badgeDiameter)

                    Text(display(count))
                        .font(.system(size: fontSize(for: count), weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: badgeDiameter * 0.82, height: badgeDiameter * 0.82)
                        .allowsTightening(true)
                }
                .scaleEffect(pulse ? 1.23 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: pulse)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("\(count) inbox tasks")
            }
        }
        .onAppear { lastCount = count }
        .onChange(of: tasks.count) { newValue in
            if newValue > lastCount {
                triggerPulse()
                triggerHaptic()
            }
            lastCount = newValue
        }
    }

    // MARK: - Constants
    private let badgeDiameter: CGFloat = 22

    // MARK: - Formatting
    private func display(_ c: Int) -> String {
        c > 99 ? "99+" : "\(c)"
    }

    private func fontSize(for count: Int) -> CGFloat {
        let text = display(count)
        switch text.count {
        case 1: return 12
        case 2: return 11
        case 3: return 9.5    // e.g. "99+"
        default: return 9
        }
    }

    // MARK: - Pulse
    private func triggerPulse() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            pulse = false
        }
    }

    // MARK: - Haptics
    private func triggerHaptic() {
        guard hapticReady else { return }
        hapticReady = false
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            hapticReady = true
        }
    }
}
