import SwiftUI
import CoreData

struct MainView: View {
    @EnvironmentObject var userDomain: UserDomain
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showQuickAddMenu = false
    @State private var showQuickAddComposer = false
    @State private var selectedTab: Tab = .today
    @State private var showDomainPickerCard = false
    @State private var showInboxTray = false

    enum Tab: String, CaseIterable {
        case today = "Today"
        case upcoming = "Upcoming"
        case browse = "Browse"
        case quickAdd = "Quick Add"

        var icon: String {
            switch self {
            case .today: return "calendar"
            case .upcoming: return "clock"
            case .browse: return "folder"
            case .quickAdd: return "plus.circle"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                topBar
                Spacer()
                content
                Spacer()
                bottomBar
            }

            // QUICK ADD MENU OVERLAY
            if showQuickAddMenu {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { showQuickAddMenu = false }
                    }

                GeometryReader { geo in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            QuickAddMenuSpaciousRight(
                                showMenu: $showQuickAddMenu,
                                onTaskTap: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        showQuickAddMenu = false
                                        showQuickAddComposer = true
                                    }
                                }
                            )
                            .padding(.bottom, 98)
                            .padding(.trailing, geo.safeAreaInsets.trailing + 8)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // DOMAIN PICKER OVERLAY
            if showDomainPickerCard {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showDomainPickerCard = false }
                    }
                HStack(alignment: .top) {
                    DomainPickerCardView(isPresented: $showDomainPickerCard)
                        .environmentObject(userDomain)
                        .padding(.leading, 12)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // INBOX TRAY OVERLAY
            if showInboxTray {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showInboxTray = false
                        }
                    }
                GeometryReader { _ in
                    VStack {
                        HStack {
                            Spacer()
                            InboxTrayListView(
                                isPresented: $showInboxTray,
                                selectedDomain: userDomain.selectedDomain
                            )
                            .padding(.trailing, 12)
                        }
                        .padding(.top, 56)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // QUICK ADD COMPOSER OVERLAY
            if showQuickAddComposer {
                QuickAddComposer(isPresented: $showQuickAddComposer)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(userDomain)
                    .zIndex(100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showQuickAddMenu)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showDomainPickerCard)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showInboxTray)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showQuickAddComposer)
    }

    // MARK: - TOP BAR
    var topBar: some View {
        HStack(spacing: 0) {
            if let domain = userDomain.selectedDomain {
                Button(action: {
                    withAnimation {
                        closeAllTransient()
                        showDomainPickerCard = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                        Image(systemName: domain.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 12)
            } else {
                Spacer().frame(width: 18)
            }

            Text(selectedTab.rawValue)
                .font(.largeTitle.bold())
                .padding(.leading, 8)

            Spacer()

            // Inbox / Tray Button
            Button(action: {
                withAnimation {
                    closeAllTransient(except: .inboxTray)
                    showInboxTray.toggle()
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tray.full")
                        .font(.title2)
                        .foregroundColor(.blue)

                    // Badge disappears while tray open
                    InboxBadgeView(
                        domain: userDomain.selectedDomain,
                        trayOpen: showInboxTray
                    )
                    .offset(x: 10, y: -8)
                    .allowsHitTesting(false)
                }
                .frame(width: 32, height: 28, alignment: .center)
                .contentShape(Rectangle())
                .accessibilityLabel("Inbox")
            }
            .padding(.trailing, 8)

            // Ellipsis (placeholder for future settings)
            Button(action: {
                withAnimation { closeAllTransient() }
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(.trailing)
        }
        .frame(height: 56)
        .background(Color.clear)
    }

    // MARK: - MAIN CONTENT
    var content: some View {
        switch selectedTab {
        case .today:
            if let domain = userDomain.selectedDomain {
                AnyView(TodayView(domain: domain))
            } else {
                AnyView(EmptyView())
            }
        case .upcoming:
            AnyView(UpcomingView())
        case .browse:
            AnyView(BrowseView())
        case .quickAdd:
            AnyView(EmptyView()) // Handled through overlay
        }
    }

    // MARK: - BOTTOM BAR
    var bottomBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Spacer()
                BottomBarItem(
                    tab: tab,
                    selectedTab: selectedTab,
                    showQuickAddMenu: showQuickAddMenu,
                    onTabSelected: { selected in
                        if selected == .quickAdd {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                closeAllTransient(except: .quickAddMenu)
                                showQuickAddMenu.toggle()
                            }
                        } else {
                            selectedTab = selected
                            withAnimation { closeAllTransient() }
                        }
                    }
                )
                Spacer()
            }
        }
        .frame(height: 90)
        .background(Color.white)
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - HELPERS
    private enum TransientOverlay { case quickAddMenu, inboxTray, domainPicker, composer }

    private func closeAllTransient(except keep: TransientOverlay? = nil) {
        if keep != .quickAddMenu { showQuickAddMenu = false }
        if keep != .inboxTray { showInboxTray = false }
        if keep != .domainPicker { showDomainPickerCard = false }
        if keep != .composer { showQuickAddComposer = false }
    }
}

// MARK: - Bottom Bar Item
struct BottomBarItem: View {
    let tab: MainView.Tab
    let selectedTab: MainView.Tab
    let showQuickAddMenu: Bool
    let onTabSelected: (MainView.Tab) -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.icon)
                .font(.system(size: 22, weight: .medium))
                .padding(.top, 10)
            Text(tab.rawValue)
                .font(.caption)
                .padding(.bottom, 12)
        }
        .foregroundColor(selectedTab == tab ? .blue : .gray)
        .onTapGesture { onTabSelected(tab) }
    }
}

// MARK: - Quick Add Menu
struct QuickAddMenuSpaciousRight: View {
    @Binding var showMenu: Bool
    var onTaskTap: () -> Void

    struct MenuItem { let label: String; let icon: String; let bold: Bool }

    let items: [MenuItem] = [
        .init(label: "Task",     icon: "checkmark.circle.fill", bold: true),
        .init(label: "Note",     icon: "note.text",            bold: false),
        .init(label: "Reminder", icon: "bell",                 bold: false),
        .init(label: "Project",  icon: "folder",               bold: false),
        .init(label: "Area",     icon: "gearshape",            bold: false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button(action: {
                    if items[i].label == "Task" {
                        showMenu = false
                        onTaskTap()
                    } else {
                        withAnimation { showMenu = false }
                    }
                }) {
                    HStack(spacing: 16) {
                        Spacer()
                        Text(items[i].label)
                            .font(items[i].bold ? .system(size: 17, weight: .bold)
                                                : .system(size: 15))
                            .foregroundColor(.black)
                        Image(systemName: items[i].icon)
                            .font(.system(size: items[i].bold ? 22 : 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(height: 54)
                    .padding(.horizontal, 18)
                }
                if i != items.count - 1 {
                    Divider()
                        .padding(.leading, 18)
                        .padding(.trailing, 18)
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(.black).opacity(0.13), radius: 14, x: 0, y: 6)
        )
        .frame(width: 230, alignment: .trailing)
    }
}
