import SwiftUI

struct DomainPickerCardView: View {
    @EnvironmentObject var userDomain: UserDomain
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(DomainType.allCases) { domain in
                Button(action: {
                    withAnimation {
                        userDomain.selectedDomain = domain
                        isPresented = false
                    }
                }) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 32, height: 32)
                            Image(systemName: domain.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        Text(domain.rawValue)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        Spacer()
                        if userDomain.selectedDomain == domain {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 18)
                }
                .background(
                    userDomain.selectedDomain == domain
                        ? Color.blue.opacity(0.08)
                        : Color.clear
                )
                .cornerRadius(12)

                if domain != DomainType.allCases.last {
                    Divider()
                        .padding(.leading, 18)
                        .padding(.trailing, 18)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(.black).opacity(0.13), radius: 14, x: 0, y: 6)
        )
        .frame(width: 230, alignment: .leading)
    }
}