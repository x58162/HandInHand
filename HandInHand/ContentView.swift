import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

struct ContentView: View {
    @State private var showingLoginMessage = false
    @State private var loginMessageTitle = ""
    @State private var loginMessage = ""

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
                    GoogleSignInButton(scheme: .light, style: .wide, action: handleGoogleSignIn)
                        .frame(height: 50)

                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                }
                .frame(maxWidth: 340)
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 26) + 42)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .alert(loginMessageTitle, isPresented: $showingLoginMessage) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(loginMessage)
        }
    }

    private func handleGoogleSignIn() {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
            !clientID.isEmpty,
            !clientID.contains("YOUR_")
        else {
            showLoginMessage(
                title: "Google 登入尚未設定",
                message: "已改用 Google 官方按鈕。要開始登入，還需要在 Xcode 設定 iOS OAuth Client ID 與反向 URL Scheme。"
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

#Preview {
    ContentView()
}
