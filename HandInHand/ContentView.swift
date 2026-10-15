import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @State private var showingStartMessage = false
    
    private let night = Color(red: 0.035, green: 0.018, blue: 0.13)
    private let violet = Color(red: 0.58, green: 0.24, blue: 0.98)
    private let pink = Color(red: 1.0, green: 0.48, blue: 0.88)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                cosmicBackground

                VStack(spacing: 0) {
                    Spacer(minLength: 38)

                    brandHeader
                        .padding(.top, 18)

                    Spacer(minLength: 10)

                    handsArtwork
                        .frame(height: geometry.size.height * 0.48)
                        .padding(.horizontal, 12)

                    Spacer(minLength: 6)

                    Button {
                        showingStartMessage = true
                    } label: {
                        Text("立即開始")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: [
                                    Color(red: 0.63, green: 0.31, blue: 1.0),
                                    Color(red: 0.87, green: 0.30, blue: 0.82)
                                ], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
                            .shadow(color: pink.opacity(0.42), radius: 18, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 34)

                    legalText
                        .padding(.top, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom == 0 ? 22 : 12, 12))
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
            .preferredColorScheme(.dark)
            .alert("歡迎來到牽手", isPresented: $showingStartMessage) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("登入流程尚未接上正式帳號驗證。")
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

    private var brandHeader: some View {
        VStack(spacing: 8) {
            Text("牽手")
                .font(.system(size: 58, weight: .regular, design: .serif))
                .tracking(8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 1, green: 0.78, blue: 0.97), pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: pink.opacity(0.7), radius: 18)

            Text("今晚，找個人聊聊。")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.94))
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var handsArtwork: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
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

private struct ReachingRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.22))
        p.addCurve(to: CGPoint(x: rect.midX - rect.width * 0.04, y: rect.midY + rect.height * 0.04),
                   control1: CGPoint(x: rect.width * 0.20, y: rect.height * 0.05),
                   control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.60))
        p.addCurve(to: CGPoint(x: rect.midX + rect.width * 0.08, y: rect.midY + rect.height * 0.08),
                   control1: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.midY - rect.height * 0.04),
                   control2: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.midY + rect.height * 0.02))
        p.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.maxY - rect.height * 0.18),
                   control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.36),
                   control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.90))
        return p
    }
}

#Preview {
    ContentView()
}

