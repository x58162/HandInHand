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

                    Spacer(minLength: 4)

                    handsArtwork
                        .frame(height: geometry.size.height * 0.47)
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
                // Load the detailed illustration when the asset is present.
                Image("CosmicLoginArtwork")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                // Keep a visible fallback until the image asset is bundled in the Xcode project.
                ReachingHandsShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.88, blue: 0.98),
                                     Color(red: 1, green: 0.60, blue: 0.86),
                                     Color(red: 0.67, green: 0.49, blue: 0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        ReachingHandsShape()
                            .stroke(.white.opacity(0.88),
                                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                    }
                    .shadow(color: pink.opacity(0.85), radius: 16)
                    .frame(width: proxy.size.width * 0.98, height: proxy.size.height * 0.82)
                    .offset(y: proxy.size.height * 0.10)
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


/// Two reaching hands drawn as scalable vector paths for the login illustration.
private struct ReachingHandsShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()

        // Left arm and open hand reaching inward.
        path.move(to: p(0.02, 0.91))
        path.addCurve(to: p(0.31, 0.60), control1: p(0.10, 0.79), control2: p(0.22, 0.65))
        path.addCurve(to: p(0.37, 0.52), control1: p(0.34, 0.58), control2: p(0.35, 0.53))
        path.addCurve(to: p(0.42, 0.44), control1: p(0.39, 0.49), control2: p(0.40, 0.45))
        path.addCurve(to: p(0.47, 0.34), control1: p(0.44, 0.41), control2: p(0.46, 0.36))
        path.addCurve(to: p(0.49, 0.31), control1: p(0.47, 0.32), control2: p(0.48, 0.30))
        path.addCurve(to: p(0.50, 0.36), control1: p(0.50, 0.31), control2: p(0.51, 0.34))
        path.addLine(to: p(0.49, 0.44))
        path.addCurve(to: p(0.53, 0.37), control1: p(0.50, 0.42), control2: p(0.51, 0.38))
        path.addCurve(to: p(0.56, 0.38), control1: p(0.54, 0.35), control2: p(0.56, 0.36))
        path.addLine(to: p(0.55, 0.47))
        path.addCurve(to: p(0.59, 0.43), control1: p(0.56, 0.46), control2: p(0.58, 0.43))
        path.addCurve(to: p(0.62, 0.46), control1: p(0.61, 0.42), control2: p(0.63, 0.44))
        path.addLine(to: p(0.60, 0.53))
        path.addCurve(to: p(0.64, 0.51), control1: p(0.61, 0.53), control2: p(0.63, 0.50))
        path.addCurve(to: p(0.66, 0.55), control1: p(0.66, 0.52), control2: p(0.67, 0.54))
        path.addCurve(to: p(0.59, 0.65), control1: p(0.64, 0.60), control2: p(0.62, 0.64))
        path.addCurve(to: p(0.52, 0.73), control1: p(0.56, 0.67), control2: p(0.54, 0.70))
        path.addLine(to: p(0.45, 0.84))
        path.closeSubpath()

        // Right arm and hand mirror the reach, with a small gap between fingertips.
        path.move(to: p(0.98, 0.91))
        path.addCurve(to: p(0.70, 0.61), control1: p(0.90, 0.79), control2: p(0.78, 0.66))
        path.addCurve(to: p(0.65, 0.54), control1: p(0.67, 0.59), control2: p(0.66, 0.55))
        path.addCurve(to: p(0.62, 0.48), control1: p(0.63, 0.52), control2: p(0.62, 0.49))
        path.addCurve(to: p(0.59, 0.40), control1: p(0.61, 0.45), control2: p(0.60, 0.42))
        path.addCurve(to: p(0.57, 0.39), control1: p(0.58, 0.38), control2: p(0.57, 0.38))
        path.addCurve(to: p(0.56, 0.44), control1: p(0.56, 0.40), control2: p(0.55, 0.42))
        path.addLine(to: p(0.57, 0.49))
        path.addCurve(to: p(0.53, 0.43), control1: p(0.56, 0.47), control2: p(0.55, 0.44))
        path.addCurve(to: p(0.51, 0.44), control1: p(0.52, 0.42), control2: p(0.51, 0.42))
        path.addLine(to: p(0.52, 0.51))
        path.addCurve(to: p(0.49, 0.48), control1: p(0.51, 0.50), control2: p(0.50, 0.48))
        path.addCurve(to: p(0.47, 0.50), control1: p(0.48, 0.47), control2: p(0.47, 0.48))
        path.addLine(to: p(0.49, 0.56))
        path.addCurve(to: p(0.45, 0.54), control1: p(0.48, 0.55), control2: p(0.46, 0.53))
        path.addCurve(to: p(0.43, 0.57), control1: p(0.44, 0.53), control2: p(0.42, 0.55))
        path.addCurve(to: p(0.50, 0.66), control1: p(0.45, 0.62), control2: p(0.47, 0.65))
        path.addCurve(to: p(0.56, 0.74), control1: p(0.53, 0.68), control2: p(0.54, 0.71))
        path.addLine(to: p(0.63, 0.84))
        path.closeSubpath()
        return path
    }
}
