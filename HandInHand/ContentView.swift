import SwiftUI

struct ContentView: View {
    @State private var showingLoginNotice = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let googlePurple = Color(red: 0.22, green: 0.13, blue: 0.31)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("HandsArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    googleLoginButton
                    appleLoginButton
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, geometry.size.height * 0.12)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .alert(alertTitle, isPresented: $showingLoginNotice) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var googleLoginButton: some View {
        Button {
            alertTitle = "Google 登入"
            alertMessage = "按鈕已建立，正式登入還需要接上牽手目前使用的 Google OAuth 與回呼流程。"
            showingLoginNotice = true
        } label: {
            HStack(spacing: 12) {
                Text("G")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        AngularGradient(
                            colors: [
                                Color(red: 0.26, green: 0.52, blue: 0.96),
                                Color(red: 0.20, green: 0.66, blue: 0.33),
                                Color(red: 0.98, green: 0.74, blue: 0.18),
                                Color(red: 0.92, green: 0.26, blue: 0.21),
                                Color(red: 0.26, green: 0.52, blue: 0.96)
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 30)

                Spacer(minLength: 0)

                Text("使用 Google 登入")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(googlePurple)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(googlePurple.opacity(0.9))
                    .frame(width: 30)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.white.opacity(0.97))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("使用 Google 登入")
    }

    private var appleLoginButton: some View {
        Button {
            alertTitle = "Apple 登入"
            alertMessage = "按鈕已建立，正式登入還需要在 Xcode 啟用 Sign in with Apple，並接上帳號驗證流程。"
            showingLoginNotice = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 30)

                Spacer(minLength: 0)

                Text("使用 Apple 登入")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 30)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color(red: 0.07, green: 0.055, blue: 0.09).opacity(0.92))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("使用 Apple 登入")
    }
}

#Preview {
    ContentView()
}
