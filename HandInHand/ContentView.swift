import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @State private var showingGoogleSetup = false
    @State private var appleMessage: String?

    private let night = Color(red: 0.035, green: 0.018, blue: 0.13)
    private let violet = Color(red: 0.58, green: 0.24, blue: 0.98)
    private let pink = Color(red: 1.0, green: 0.48, blue: 0.88)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cosmicBackground
                starField
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 26)

                    brandHeader
                        .padding(.top, 22)

                    Spacer(minLength: 18)

                    handsArtwork
                        .frame(height: geometry.size.height * 0.30)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 14)

                    VStack(spacing: 16) {
                        googleButton
                        appleButton
                    }
                    .padding(.horizontal, 28)

                    legalText
                        .padding(.top, 24)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom == 0 ? 22 : 12, 12))
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
            .preferredColorScheme(.dark)
            .alert("Google 登入尚未設定", isPresented: $showingGoogleSetup) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("登入畫面已完成。要啟用 Google 帳號驗證，還需要在 Xcode 加入 GoogleSignIn 套件，並設定 OAuth Client ID 與 URL Scheme。")
            }
            .alert("Apple 登入", isPresented: Binding(
                get: { appleMessage != nil },
                set: { if !$0 { appleMessage = nil } }
            )) {
                Button("好", role: .cancel) { appleMessage = nil }
            } message: {
                Text(appleMessage ?? "")
            }
        }
    }

    private var cosmicBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.015, blue: 0.10),
                    Color(red: 0.12, green: 0.035, blue: 0.30),
                    Color(red: 0.29, green: 0.07, blue: 0.42),
                    Color(red: 0.055, green: 0.025, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(violet.opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 130, y: -170)

            Circle()
                .fill(pink.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 85)
                .offset(x: -130, y: 150)

            Ellipse()
                .fill(Color(red: 0.32, green: 0.14, blue: 0.65).opacity(0.5))
                .frame(height: 180)
                .blur(radius: 70)
                .offset(y: 370)
        }
        .ignoresSafeArea()
    }

    private var starField: some View {
        GeometryReader { proxy in
            ForEach(0..<85, id: \.self) { index in
                let x = CGFloat((index * 73 + 19) % 997) / 997 * proxy.size.width
                let y = CGFloat((index * 137 + 41) % 991) / 991 * proxy.size.height
                let size: CGFloat = index.isMultiple(of: 9) ? 3 : (index.isMultiple(of: 3) ? 1.8 : 1.1)

                Circle()
                    .fill(Color.white.opacity(index.isMultiple(of: 4) ? 0.9 : 0.48))
                    .frame(width: size, height: size)
                    .shadow(color: pink.opacity(0.9), radius: size * 2)
                    .position(x: x, y: y)
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 10) {
            Text("牽手")
                .font(.system(size: 68, weight: .regular, design: .serif))
                .tracking(8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 1, green: 0.78, blue: 0.97), pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: pink.opacity(0.7), radius: 18)

            Text("Q I A N   S H O U")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.85))

            Text("今晚，找個人聊聊。")
                .font(.system(size: 19, weight: .medium, design: .serif))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.94))
                .padding(.top, 9)

            Text("VOICE     ·     FRIENDS     ·     LIVE")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(Color.white.opacity(0.68))
                .padding(.top, 1)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var handsArtwork: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: [pink.opacity(0.9), violet.opacity(0.15), pink.opacity(0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.5
                    )
                    .frame(width: min(proxy.size.width * 0.72, 270),
                           height: min(proxy.size.width * 0.72, 270))
                    .shadow(color: pink.opacity(0.5), radius: 15)

                Circle()
                    .fill(
                        RadialGradient(colors: [violet.opacity(0.28), .clear],
                                       center: .center, startRadius: 20, endRadius: 150)
                    )
                    .frame(width: 300, height: 300)

                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: min(proxy.size.width * 0.40, 145), weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white.opacity(0.95), pink)
                    .shadow(color: pink.opacity(0.9), radius: 20)
                    .rotationEffect(.degrees(-12))

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.96))
                    .shadow(color: pink, radius: 14)
                    .offset(x: proxy.size.width * 0.28, y: -proxy.size.height * 0.30)

                Image(systemName: "sparkle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white)
                    .shadow(color: pink, radius: 10)
                    .offset(x: -proxy.size.width * 0.30, y: proxy.size.height * 0.18)

                Image(systemName: "sparkle")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(pink)
                    .offset(x: proxy.size.width * 0.30, y: proxy.size.height * 0.27)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var googleButton: some View {
        Button {
            showingGoogleSetup = true
        } label: {
            HStack(spacing: 14) {
                Text("G")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.23, green: 0.66, blue: 0.33),
                            Color(red: 0.98, green: 0.74, blue: 0.02),
                            Color(red: 0.92, green: 0.26, blue: 0.21)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32)

                Text("使用 Google 登入")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.13, green: 0.08, blue: 0.28))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(violet)
            }
            .padding(.horizontal, 22)
            .frame(height: 58)
            .background(
                LinearGradient(colors: [.white, Color(red: 0.94, green: 0.87, blue: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: pink.opacity(0.24), radius: 16, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                   credential.identityToken != nil {
                    appleMessage = "已取得 Apple 登入憑證。正式登入仍需將憑證送到你的後端驗證，才能建立牽手帳號工作階段。"
                } else {
                    appleMessage = "Apple 沒有回傳可用的登入憑證，請再試一次。"
                }
            case .failure(let error):
                let authError = error as? ASAuthorizationError
                if authError?.code != .canceled {
                    appleMessage = "登入未完成，請稍後再試。"
                }
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 58)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))
        .shadow(color: violet.opacity(0.3), radius: 14, y: 5)
        .accessibilityLabel("使用 Apple 登入")
    }

    private var legalText: some View {
        VStack(spacing: 7) {
            Text("登入即表示您同意")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 8) {
                Button("《服務條款》") { }
                Text("與")
                    .foregroundStyle(.white.opacity(0.78))
                Button("《隱私權政策》") { }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(red: 1, green: 0.68, blue: 0.96))
            .underline()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
}
