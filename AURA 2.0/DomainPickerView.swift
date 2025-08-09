import SwiftUI

struct DomainPickerView: View {
    @EnvironmentObject var userDomain: UserDomain

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            // Centered Card
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Text("Choose your domain")
                            .font(.title2)
                            .bold()
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                        ForEach(DomainType.allCases) { domain in
                            Button(action: {
                                userDomain.selectedDomain = domain
                            }) {
                                HStack(spacing: 16) {
                                    Spacer()
                                    Text(domain.rawValue)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.black)
                                    Image(systemName: domain.icon)
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                .frame(height: 54)
                                .padding(.horizontal, 24)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .opacity(userDomain.selectedDomain == domain ? 0.5 : 0)
                            )
                            .padding(.vertical, 4)

                            if domain != DomainType.allCases.last {
                                Divider()
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color(.black).opacity(0.16), radius: 18, x: 0, y: 8)
                    )
                    .frame(width: 270)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
