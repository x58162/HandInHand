import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn

struct ContentView: View {
    @State private var showingLoginMessage = false
    @State private var loginMessageTitle = ""
    @State private var loginMessage = ""

    private let brandPink = Color(red: 1.0, green: 0.77, blue: 0.97)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("HandsArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    brandHeader
                        .padding(.top, geometry.size.height * 0.19)

                    Spacer(minLength: 12)

                    let buttonWidth = min(geometry.size.width - 60, 312)

                    VStack(spacing: 12) {
                        OfficialGoogleSignInButton(action: handleGoogleSignIn)
                            // Google's official button draws a 4pt inset border/shadow on every side.
                            // Add 8pt to its container so the visible white background matches Apple's width.
                            .frame(width: buttonWidth + 8, height: 48)

                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: handleAppleSignIn
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(width: buttonWidth, height: 48)
                        .cornerRadius(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, geometry.size.height * 0.17)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "zh_TW"))
        .alert(loginMessageTitle, isPresented: $showingLoginMessage) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(loginMessage)
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 7) {
            Text("牽手")
                .font(.system(size: 58, weight: .medium, design: .serif))
                .tracking(8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 1.0, green: 0.84, blue: 0.99),
                            brandPink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: brandPink.opacity(0.9), radius: 18)
                .shadow(color: Color.purple.opacity(0.75), radius: 28)

            Text("Q I A N   S H O U")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.92))

            Text("今晚，找個人聊聊。")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.98))
                .shadow(color: brandPink.opacity(0.7), radius: 8)
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func handleGoogleSignIn() {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
            !clientID.isEmpty,
            !clientID.contains("YOUR_")
        else {
            showLoginMessage(
                title: "Google 登入尚未設定",
                message: "還需要在 Xcode 設定 iOS OAuth Client ID 與反向 URL Scheme。"
            )
            return
        }

        let serverClientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )

        guard let presentingViewController = UIApplication.shared.rootViewController else {
            showLoginMessage(
                title: "無法開啟 Google 登入",
                message: "目前找不到可顯示登入畫面的視窗，請稍後再試。"
            )
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error {
                showLoginMessage(title: "Google 登入未完成", message: error.localizedDescription)
                return
            }

            guard let result else {
                showLoginMessage(title: "Google 登入未完成", message: "Google 沒有傳回登入結果，請再試一次。")
                return
            }

            let email = result.user.profile?.email ?? "Google 帳號"
            showLoginMessage(
                title: "Google 身分驗證成功",
                message: "已驗證：\(email)。牽手帳號伺服器的登入／建立帳號流程尚待串接。"
            )
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard authorization.credential is ASAuthorizationAppleIDCredential else {
                showLoginMessage(
                    title: "Apple 登入未完成",
                    message: "Apple 沒有傳回有效的登入憑證，請再試一次。"
                )
                return
            }

            showLoginMessage(
                title: "Apple 身分驗證成功",
                message: "Apple 已完成身分驗證。牽手帳號伺服器的登入／建立帳號流程尚待串接。"
            )

        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }

            showLoginMessage(title: "Apple 登入未完成", message: error.localizedDescription)
        }
    }

    private func showLoginMessage(title: String, message: String) {
        loginMessageTitle = title
        loginMessage = message
        showingLoginMessage = true
    }
}

private extension UIApplication {
    var rootViewController: UIViewController? {
        let activeWindowScene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return activeWindowScene?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}


private struct OfficialGoogleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = .light
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        uiView.style = .wide
        uiView.colorScheme = .light
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}

#Preview {
    ContentView()
}
