import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn

struct ContentView: View {
    @State private var signedInUser: SignedInUser?
    @State private var pendingProfile: PendingProfile?
    @State private var sessionToken = ""
    @State private var serverUserId = ""
    @State private var isAuthenticating = false
    @State private var showingLoginMessage = false
    @State private var loginMessageTitle = ""
    @State private var loginMessage = ""

    private let brandPink = Color(red: 1.0, green: 0.77, blue: 0.97)

    var body: some View {
        Group {
            if let signedInUser {
                MainInterfaceView(
                    user: signedInUser,
                    sessionToken: sessionToken,
                    userId: serverUserId
                ) {
                    logout()
                }
            } else {
                loginScreen
            }
        }
        .fullScreenCover(item: $pendingProfile) { pending in
            ProfileSetupView(pendingProfile: pending) { completedUser in
                serverUserId = completedUser.userId
                signedInUser = SignedInUser(
                    displayName: completedUser.displayName,
                    email: completedUser.email,
                    provider: completedUser.provider == "apple" ? "Apple" : "Google"
                )
                pendingProfile = nil
            }
            .interactiveDismissDisabled()
        }
        .alert(loginMessageTitle, isPresented: $showingLoginMessage) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(loginMessage)
        }
    }

    private var loginScreen: some View {
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

                    VStack(alignment: .leading, spacing: 12) {
                        OfficialGoogleSignInButton(action: handleGoogleSignIn)
                            .frame(width: buttonWidth + 8, height: 48)

                        OfficialAppleSignInButton(completion: handleAppleSignIn)
                            .frame(width: buttonWidth, height: 40)
                            .padding(.leading, 4)
                            .frame(width: buttonWidth + 8, height: 48, alignment: .leading)
                    }
                    .frame(width: buttonWidth + 8, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, geometry.size.height * 0.17)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .environment(\.locale, Locale(identifier: "zh_TW"))
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

            guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else {
                showLoginMessage(
                    title: "無法完成 Google 登入",
                    message: "Google 沒有回傳 ID Token，請重新登入。"
                )
                return
            }

            isAuthenticating = true
            Task {
                do {
                    let response = try await VoiceServerAPIClient.shared.verifyGoogle(idToken: idToken)
                    sessionToken = response.sessionToken
                    serverUserId = response.user.userId
                    isAuthenticating = false

                    if response.needsProfile || !response.user.profileCompleted {
                        pendingProfile = PendingProfile(
                            sessionToken: response.sessionToken,
                            serverUser: response.user
                        )
                    } else {
                        signedInUser = SignedInUser(
                            displayName: response.user.displayName,
                            email: response.user.email,
                            provider: response.user.provider == "apple" ? "Apple" : "Google"
                        )
                    }
                } catch {
                    isAuthenticating = false
                    showLoginMessage(
                        title: "牽手伺服器登入失敗",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                showLoginMessage(
                    title: "Apple 登入未完成",
                    message: "Apple 沒有傳回有效的登入憑證，請再試一次。"
                )
                return
            }

            // The current server ZIP contains no Apple token-verification endpoint.
            // Do not treat local Apple authorization alone as a completed member login.
            showLoginMessage(
                title: "Apple 身分驗證成功",
                message: "Apple 已完成裝置端驗證，但牽手伺服器目前尚未實作 Apple 憑證驗證。要先接通會員資料庫，請暫時使用 Google 登入。"
            )

        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }

            showLoginMessage(title: "Apple 登入未完成", message: error.localizedDescription)
        }
    }

    private func logout() {
        let token = sessionToken
        signedInUser = nil
        pendingProfile = nil
        sessionToken = ""
        serverUserId = ""

        Task {
            await VoiceServerAPIClient.shared.logout(sessionToken: token)
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

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = .light
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )

        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(equalTo: container.widthAnchor),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let button = uiView.subviews.first(where: { $0 is GIDSignInButton }) as? GIDSignInButton else {
            return
        }
        button.style = .wide
        button.colorScheme = .light
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


private struct OfficialAppleSignInButton: UIViewRepresentable {
    let completion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.anchorView = container

        // Keep Apple's native authorization flow, while aligning the visual label
        // with Google's left-aligned icon/text layout.
        let button = UIButton(type: .system)
        button.backgroundColor = .black
        button.layer.cornerRadius = 2
        button.clipsToBounds = true
        button.tintColor = .white
        button.accessibilityLabel = "使用 Apple 登入"
        button.accessibilityIdentifier = "AppleSignInButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )

        let appleIcon = UIImageView(image: UIImage(systemName: "apple.logo"))
        appleIcon.tintColor = .white
        appleIcon.contentMode = .scaleAspectFit
        appleIcon.isAccessibilityElement = false
        appleIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "使用 Apple 登入"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.isAccessibilityElement = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(appleIcon)
        button.addSubview(titleLabel)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            appleIcon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 10),
            appleIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            appleIcon.widthAnchor.constraint(equalToConstant: 24),
            appleIcon.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: appleIcon.trailingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate,
        ASAuthorizationControllerPresentationContextProviding {
        private let completion: (Result<ASAuthorization, Error>) -> Void
        private var authorizationController: ASAuthorizationController?
        weak var anchorView: UIView?
        private weak var presentationWindow: UIWindow?

        init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.completion = completion
        }

        @objc func didTap() {
            // Present Apple's system authorization UI from the actual window
            // containing this button, rather than a guessed or empty window.
            guard let window = anchorView?.window else {
                completion(.failure(NSError(
                    domain: "HandInHand.AppleSignIn",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "目前無法取得登入視窗，請稍後再試。"]
                )))
                return
            }
            presentationWindow = window

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            authorizationController = controller
            controller.performRequests()
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            DispatchQueue.main.async {
                self.completion(.success(authorization))
            }
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            DispatchQueue.main.async {
                self.completion(.failure(error))
            }
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            if let presentationWindow {
                return presentationWindow
            }

            if let window = anchorView?.window {
                return window
            }

            let activeScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }

            if let window = activeScene?.windows.first(where: { $0.isKeyWindow }) {
                return window
            }

            // didTap() checks the button's window before starting a request.
            // If that window becomes unavailable during authorization, use an
            // existing window from the foreground scene. Never create a detached
            // empty presentation window as a fallback.
            if let window = activeScene?.windows.first {
                return window
            }

            // The request must have a real app window to present from. This path
            // should be unreachable because didTap() validates the anchor first.
            preconditionFailure("Apple Sign In requires an active app window.")
        }
    }
}

#Preview {
    ContentView()
}
