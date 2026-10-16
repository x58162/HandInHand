import SwiftUI

struct SignedInUser {
    let displayName: String
    let email: String
    let provider: String
}

private enum MainTab: String, CaseIterable, Identifiable {
    case home = "首頁"
    case discover = "探索"
    case messages = "訊息"
    case profile = "我的"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "safari.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

private struct DemoVoiceRoom: Identifiable {
    let id: Int
    let title: String
    let host: String
    let topic: String
    let listeners: Int
    let symbol: String
    let tint: Color
    let isHot: Bool

    static let samples: [DemoVoiceRoom] = [
        DemoVoiceRoom(id: 1, title: "今晚不想一個人", host: "小星球", topic: "深夜聊天", listeners: 28, symbol: "moon.stars.fill", tint: Palette.violet, isHot: true),
        DemoVoiceRoom(id: 2, title: "放首歌陪你", host: "阿沐", topic: "音樂・點歌", listeners: 16, symbol: "music.note", tint: Palette.rose, isHot: true),
        DemoVoiceRoom(id: 3, title: "慢慢認識新朋友", host: "晴天", topic: "交朋友", listeners: 9, symbol: "heart.fill", tint: Palette.mint, isHot: false),
        DemoVoiceRoom(id: 4, title: "下班後的放鬆角落", host: "小宇", topic: "生活・閒聊", listeners: 12, symbol: "cup.and.saucer.fill", tint: Palette.amber, isHot: false)
    ]
}

private enum Palette {
    static let background = Color(red: 0.975, green: 0.965, blue: 0.99)
    static let ink = Color(red: 0.16, green: 0.13, blue: 0.23)
    static let muted = Color(red: 0.49, green: 0.46, blue: 0.56)
    static let violet = Color(red: 0.48, green: 0.31, blue: 0.82)
    static let rose = Color(red: 0.90, green: 0.40, blue: 0.65)
    static let mint = Color(red: 0.28, green: 0.65, blue: 0.58)
    static let amber = Color(red: 0.88, green: 0.58, blue: 0.25)
    static let line = Color(red: 0.91, green: 0.89, blue: 0.94)
}

struct MainInterfaceView: View {
    let user: SignedInUser
    let onLogout: () -> Void

    @State private var selectedTab: MainTab = .home
    @State private var selectedRoom: DemoVoiceRoom?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    pageContent
                        .padding(.bottom, 20)
                }

                bottomBar
            }
        }
        .sheet(item: $selectedRoom) { room in
            RoomPreviewSheet(room: room)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("牽手")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.ink)
                Text("QIAN SHOU")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            Button {
                selectedTab = .messages
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知")

            Button {
                selectedTab = .profile
            } label: {
                Text(userInitial)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(colors: [Palette.violet, Palette.rose], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("個人資料")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedTab {
        case .home:
            homePage
        case .discover:
            discoverPage
        case .messages:
            messagesPage
        case .profile:
            profilePage
        }
    }

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 23) {
            VStack(alignment: .leading, spacing: 5) {
                Text("晚上好，\(greetingName)！")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("今天想找個人聊聊嗎？")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 8)

            welcomeCard

            VStack(alignment: .leading, spacing: 13) {
                sectionHeading("找個話題開始聊", detail: "選一種今晚的心情")
                HStack(spacing: 9) {
                    topicChip("深夜聊天", symbol: "moon.stars.fill", color: Palette.violet)
                    topicChip("音樂點歌", symbol: "music.note", color: Palette.rose)
                }
                HStack(spacing: 9) {
                    topicChip("交朋友", symbol: "heart.fill", color: Palette.mint)
                    topicChip("輕鬆閒聊", symbol: "cup.and.saucer.fill", color: Palette.amber)
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    sectionHeading("正在熱聊", detail: "看看大家都在聊什麼")
                    Spacer()
                    Button("全部") { selectedTab = .discover }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.violet)
                }

                ForEach(DemoVoiceRoom.samples.prefix(3)) { room in
                    roomCard(room)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.violet)
                VStack(alignment: .leading, spacing: 3) {
                    Text("第一次來牽手？")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("逛逛語音房，找到合拍的聊天夥伴。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    private var welcomeCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(colors: [Palette.violet, Color(red: 0.64, green: 0.37, blue: 0.80), Palette.rose], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 145, height: 145)
                .offset(x: 30, y: -44)

            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 1)
                .frame(width: 105, height: 105)
                .offset(x: -32, y: 54)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text("今晚的相遇，從這裡開始")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))

                Text("別讓心情，\n只留給自己。")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(.white)

                Button {
                    selectedTab = .discover
                } label: {
                    HStack(spacing: 7) {
                        Text("探索語音房")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.violet)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .frame(height: 205)
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }

    private var discoverPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("探索語音房")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("依照你的心情，選一間房間加入聊天。")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                topicChip("全部房間", symbol: "square.grid.2x2.fill", color: Palette.violet)
                topicChip("熱門", symbol: "flame.fill", color: Palette.rose)
            }

            ForEach(DemoVoiceRoom.samples) { room in
                roomCard(room)
            }

            demoNotice
        }
        .padding(.horizontal, 20)
    }

    private var messagesPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 34))
                .foregroundStyle(Palette.violet)
                .frame(width: 82, height: 82)
                .background(Palette.violet.opacity(0.10), in: Circle())

            Text("訊息")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("登入介面已建立，聊天訊息功能會在接上會員伺服器後啟用。")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.muted)
                .lineSpacing(4)
                .frame(maxWidth: 280)

            demoNotice
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 75)
    }

    private var profilePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("我的")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.top, 8)

            HStack(spacing: 14) {
                Text(userInitial)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(LinearGradient(colors: [Palette.violet, Palette.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.displayName.isEmpty ? "牽手使用者" : user.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(user.email.isEmpty ? "已完成\(user.provider)身分驗證" : user.email)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                    Text("\(user.provider) 驗證")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.violet)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Palette.violet.opacity(0.10), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(17)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                Label("帳號與安全", systemImage: "lock.shield")
                Divider().overlay(Palette.line)
                Label("通知設定", systemImage: "bell")
                Divider().overlay(Palette.line)
                Label("幫助與回饋", systemImage: "questionmark.circle")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(17)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))

            demoNotice

            Button(role: .destructive, action: onLogout) {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("返回登入畫面")
                    Spacer()
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var demoNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Palette.violet)
            Text("目前是介面預覽模式。牽手會員伺服器、即時房間資料與聊天功能尚未串接。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Palette.violet : Palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
    }

    private func topicChip(_ title: String, symbol: String, color: Color) -> some View {
        Button {
            selectedTab = .discover
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func roomCard(_ room: DemoVoiceRoom) -> some View {
        Button {
            selectedRoom = room
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(room.tint.opacity(0.13))
                        .frame(width: 62, height: 62)
                    Image(systemName: room.symbol)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(room.tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(room.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if room.isHot {
                            Text("熱門")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.rose)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Palette.rose.opacity(0.10), in: Capsule())
                        }
                    }
                    Text("\(room.host)  ・  \(room.topic)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle().fill(Palette.mint).frame(width: 5, height: 5)
                        Text("\(room.listeners) 人正在聽")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.muted)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.muted.opacity(0.7))
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var userInitial: String {
        let name = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(name.first ?? "牽")
    }

    private var greetingName: String {
        let name = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "朋友" }
        return String(name.prefix(12))
    }
}

private struct RoomPreviewSheet: View {
    let room: DemoVoiceRoom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(room.tint.opacity(0.12)).frame(width: 105, height: 105)
                    Image(systemName: room.symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(room.tint)
                }

                Text(room.title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Text("\(room.host)  ・  \(room.topic)")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)

                Label("\(room.listeners) 人正在聽", systemImage: "headphones")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.violet)

                Text("語音房介面預覽")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)

                Button {
                    dismiss()
                } label: {
                    Text("返回房間列表")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(LinearGradient(colors: [Palette.violet, Palette.rose], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
    }
}
