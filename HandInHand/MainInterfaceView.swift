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
    let sessionToken: String
    let userId: String
    let onLogout: () -> Void

    @StateObject private var roomStore = VoiceRoomStore()
    @State private var selectedTab: MainTab = .home
    @State private var selectedRoom: VoiceRoom?

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
        .onAppear {
            roomStore.connect()
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
                    sectionHeading("正在開放的語音房", detail: "即時同步伺服器房間")
                    Spacer()
                    Button("全部") { selectedTab = .discover }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.violet)
                }

                roomConnectionStatus

                if roomStore.rooms.isEmpty {
                    emptyRoomsCard
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(Array(roomStore.rooms.prefix(4))) { room in
                            roomCard(room)
                        }
                    }
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
                    Text("看看目前開放的語音房，選擇有興趣的話題。")
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
                Text("房間名稱、人數及房主資料同步自牽手伺服器。")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 8)

            roomConnectionStatus

            HStack(spacing: 8) {
                topicChip("全部房間", symbol: "square.grid.2x2.fill", color: Palette.violet)
                Button {
                    roomStore.refresh()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.clockwise")
                        Text("重新整理")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.rose)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.rose.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if roomStore.rooms.isEmpty {
                emptyRoomsCard
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(roomStore.rooms) { room in
                        roomCard(room)
                    }
                }
            }

            Text("房間列表只顯示目前伺服器上正在開放的房間。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
    }

    private var roomConnectionStatus: some View {
        HStack(spacing: 8) {
            switch roomStore.connectionState {
            case .connecting:
                ProgressView().controlSize(.small)
                Text("正在連接牽手語音伺服器…")
                    .foregroundStyle(Palette.muted)
            case .connected:
                Circle().fill(Palette.mint).frame(width: 7, height: 7)
                Text("已連線・\(roomStore.rooms.count) 間開放房間")
                    .foregroundStyle(Palette.muted)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.rose)
                Text("連線失敗：\(message)")
                    .foregroundStyle(Palette.rose)
                    .lineLimit(2)
            case .disconnected:
                Image(systemName: "wifi.slash")
                    .foregroundStyle(Palette.muted)
                Text("尚未連線")
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 0)
            Button {
                roomStore.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.violet)
                    .padding(8)
                    .background(Palette.violet.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新整理房間")
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.vertical, 3)
    }

    private var emptyRoomsCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Palette.violet.opacity(0.09)).frame(width: 66, height: 66)
                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.violet)
            }

            Text(emptyRoomTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.ink)

            Text(emptyRoomDetail)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                roomStore.refresh()
            } label: {
                Text("重新載入")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.violet)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(Palette.violet.opacity(0.09), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
    }

    private var emptyRoomTitle: String {
        switch roomStore.connectionState {
        case .connecting: return "正在尋找語音房"
        case .failed: return "暫時無法取得房間"
        case .connected: return "目前沒有正在開放的房間"
        case .disconnected: return "尚未連接語音伺服器"
        }
    }

    private var emptyRoomDetail: String {
        switch roomStore.connectionState {
        case .connecting:
            return "正在向牽手伺服器讀取即時房間列表。"
        case .failed(let message):
            return "請確認伺服器網址與網路連線。\n\(message)"
        case .connected:
            return "目前沒有人開啟語音房，稍後可以再回來看看。"
        case .disconnected:
            return "請重新連線後再查看房間。"
        }
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

            Text("訊息功能會在接上牽手即時聊天服務後啟用。")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.muted)
                .lineSpacing(4)
                .frame(maxWidth: 280)
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
                    Text("\(user.provider) 會員")
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

            Button(role: .destructive, action: performLogout) {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("登出牽手")
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
            Rectangle().fill(Palette.line).frame(height: 1)
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

    private func roomCard(_ room: VoiceRoom) -> some View {
        Button {
            selectedRoom = room
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    roomCover(room)
                        .frame(height: 118)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(room.mode == "personal" ? "個人房" : "語音房")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.22), in: Capsule())

                            if room.locked {
                                Label("已鎖定", systemImage: "lock.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.35), in: Capsule())
                            }
                            Spacer()
                        }

                        Text(room.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(.white)

                        Text("房主・\(room.ownerName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(1)
                    }
                    .padding(14)
                    .foregroundStyle(.white)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))

                HStack(spacing: 13) {
                    Label("\(room.userCount) 人", systemImage: "person.2.fill")
                    Label("\(room.micCount)/8 麥", systemImage: "mic.fill")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.muted)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1))
            .shadow(color: Palette.violet.opacity(0.05), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func roomCover(_ room: VoiceRoom) -> some View {
        if let url = room.displayImageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackRoomArtwork(room)
                }
            }
        } else {
            fallbackRoomArtwork(room)
        }
    }

    private func fallbackRoomArtwork(_ room: VoiceRoom) -> some View {
        ZStack {
            LinearGradient(
                colors: [Palette.violet, Color(red: 0.26, green: 0.18, blue: 0.42), Palette.rose.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 150, height: 150)
                .offset(x: 105, y: -45)

            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 1)
                .frame(width: 95, height: 95)
                .offset(x: -100, y: 42)

            Image(systemName: room.mode == "personal" ? "person.crop.circle.fill" : "waveform")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private func performLogout() {
        roomStore.disconnect()
        onLogout()
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
    let room: VoiceRoom
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Group {
                    if let url = room.displayImageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 108, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Text(room.name)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Text("房主：\(room.ownerName)")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)

                HStack(spacing: 16) {
                    Label("\(room.userCount) 人在線", systemImage: "person.2.fill")
                    Label("\(room.micCount)/8 麥", systemImage: "mic.fill")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.violet)

                Text(room.locked ? "這間房目前已上鎖。" : "房間資料來自牽手伺服器。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)

                Text("目前先完成真實房間列表與圖片顯示；加入房間與即時語音會接著串接。")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

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

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(colors: [Palette.violet, Palette.rose], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "waveform")
                .font(.system(size: 35, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
