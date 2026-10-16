import SwiftUI

struct VoiceRoomDetailView: View {
    let room: VoiceRoom
    let sessionToken: String
    let currentUserId: String
    let onLeave: () -> Void

    @StateObject private var store: VoiceRoomSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var chatDraft = ""
    @FocusState private var isChatInputFocused: Bool

    init(
        room: VoiceRoom,
        sessionToken: String,
        currentUserId: String,
        onLeave: @escaping () -> Void
    ) {
        self.room = room
        self.sessionToken = sessionToken
        self.currentUserId = currentUserId
        self.onLeave = onLeave
        _store = StateObject(
            wrappedValue: VoiceRoomSessionStore(roomId: room.roomId, sessionToken: sessionToken, currentUserId: currentUserId)
        )
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
        count: 4
    )

    var body: some View {
        ZStack {
            Color(red: 0.965, green: 0.945, blue: 0.99).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        seatsPanel
                        roomChatPanel

                        if isRoomManager, let snapshot = store.snapshot,
                           !snapshot.pendingMicRequests.isEmpty {
                            pendingRequests(snapshot.pendingMicRequests)
                        }

                        if let message = store.micMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Palette.violet)
                                Text(message)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                                Button {
                                    store.clearMicMessage()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }

                        if let errorMessage = store.errorMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Palette.rose)
                                Text(errorMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                                Button("重試") {
                                    store.connect()
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.violet)
                            }
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }

                bottomControls
            }
        }
        .onAppear {
            store.connect()
        }
        .onDisappear {
            store.leave()
        }
        .statusBarHidden(false)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: leaveRoom) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("離開房間")

            VStack(alignment: .leading, spacing: 3) {
                Text(room.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isJoined ? Palette.mint : Palette.amber)
                        .frame(width: 6, height: 6)
                    Text(store.isJoined ? "房間已連線" : store.status)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Label("\(store.snapshot?.userCount ?? room.userCount)", systemImage: "person.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.violet)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Palette.violet.opacity(0.09), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    private var seatsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("語音麥位")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("共 8 個位置・點選空位申請上麥")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }

                Spacer()

                Text("\(occupiedSeatCount)/8")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.violet)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Palette.violet.opacity(0.09), in: Capsule())
            }

            LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
                ForEach(0..<8, id: \.self) { index in
                    seatItem(at: index)
                }
            }

            HStack(spacing: 8) {
                Circle().fill(Palette.mint).frame(width: 7, height: 7)
                Text("空位可申請")
                Spacer()
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(Palette.muted)
                Text("尚未開麥")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.top, 2)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
        .shadow(color: Palette.violet.opacity(0.04), radius: 12, y: 4)
    }

    private var roomChatPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(Palette.violet)
                Text("房間聊天")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(store.chatMessages.count) 則")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        if store.chatMessages.isEmpty {
                            Text(store.isJoined ? "傳送第一則訊息，和房內的人打聲招呼吧。" : "連線後即可開始聊天。")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 9)
                        }

                        ForEach(store.chatMessages) { message in
                            chatMessageRow(message)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 118)
                .onChange(of: store.chatMessages.count) { _ in
                    guard let lastMessage = store.chatMessages.last else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    if let lastMessage = store.chatMessages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding(13)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 1))
    }

    private func chatMessageRow(_ message: VoiceRoomChatMessage) -> some View {
        let isOwnMessage = message.userId == currentUserId
        let nameColor: Color = isOwnMessage ? Palette.rose : Palette.violet
        let bubbleColor: Color = isOwnMessage ? Palette.violet.opacity(0.07) : Palette.background
        let timeText = message.timestamp.formatted(date: .omitted, time: .shortened)

        return HStack(alignment: .top, spacing: 8) {
            Text(message.userName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .frame(maxWidth: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeText)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 10))
        .id(message.id)
    }

    private func seatItem(at index: Int) -> some View {
        let seat = store.snapshot?.seats.first(where: { $0.index == index })
        let member = seat?.userId.flatMap { userId in
            store.snapshot?.users.first(where: { $0.userId == userId })
        }
        let isSelf = member?.userId == currentUserId
        let isEmpty = seat?.userId == nil

        return Button {
            guard store.isJoined else { return }
            if isEmpty {
                store.requestMic(seatIndex: index)
            } else if isSelf {
                store.releaseMic()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    seatAvatar(member: member, empty: isEmpty, index: index)
                        .frame(width: 54, height: 54)

                    if !isEmpty, let seat {
                        Image(systemName: seat.muted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(seat.muted ? Palette.rose : Palette.mint, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .offset(x: 3, y: 2)
                    }
                }

                Text(isEmpty ? "麥位 \(index + 1)" : (member?.nickname ?? "使用者"))
                    .font(.system(size: 10, weight: isSelf ? .bold : .medium))
                    .foregroundStyle(isSelf ? Palette.violet : Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(isEmpty ? "空位" : (isSelf ? "我" : (member?.role == "owner" ? "房主" : "已上麥")))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isEmpty ? Palette.muted : Palette.violet)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .opacity(isEmpty || isSelf ? 1 : 0.96)
        }
        .buttonStyle(.plain)
        .disabled(!store.isJoined || (!isEmpty && !isSelf))
        .accessibilityLabel(isEmpty ? "第 \(index + 1) 麥，申請上麥" : "\(member?.nickname ?? "使用者")，第 \(index + 1) 麥")
    }

    @ViewBuilder
    private func seatAvatar(member: VoiceRoomMember?, empty: Bool, index: Int) -> some View {
        if empty {
            ZStack {
                Circle()
                    .fill(Palette.violet.opacity(0.07))
                    .overlay(Circle().strokeBorder(Palette.violet.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                Image(systemName: "mic.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Palette.violet.opacity(0.65))
                Text("\(index + 1)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.violet)
                    .offset(y: 26)
            }
        } else if let member, let url = avatarURL(member.avatarURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    initialsAvatar(member.nickname)
                }
            }
            .clipShape(Circle())
            .overlay(Circle().stroke(isCurrentUser(member.userId) ? Palette.violet : .white, lineWidth: isCurrentUser(member.userId) ? 3 : 2))
        } else {
            initialsAvatar(member?.nickname ?? "牽")
        }
    }

    private func initialsAvatar(_ name: String) -> some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Palette.violet, Palette.rose], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(String(name.first ?? "牽"))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private func pendingRequests(_ requests: [VoiceRoomPendingMicRequest]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Palette.violet)
                Text("上麥申請")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(requests.count) 位")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }

            ForEach(requests) { request in
                HStack(spacing: 10) {
                    initialsAvatar(request.nickname)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(request.nickname)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("申請第 \(request.seatIndex + 1) 麥")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.muted)
                    }

                    Spacer()

                    Button("拒絕") { store.denyMic(request) }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.rose)

                    Button("同意") { store.approveMic(request) }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.violet, in: Capsule())
                }
            }
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
    }

    private var bottomControls: some View {
        VStack(spacing: 8) {
            if !store.isJoined {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(store.status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Button {
                        store.connect()
                    } label: {
                        Text("重新連線")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.violet)
                    }
                }
            }

            chatComposer

            HStack(spacing: 10) {
                Button {
                    if isCurrentUserOnMic {
                        store.toggleMicrophone()
                    } else {
                        store.requestMic()
                    }
                } label: {
                    Label(
                        microphoneButtonTitle,
                        systemImage: microphoneButtonSymbol
                    )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(store.isMicrophoneOn ? Palette.rose : Palette.violet, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!store.isJoined || store.isStartingMicrophone)

                Button(action: leaveRoom) {
                    Label("離開房間", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var chatComposer: some View {
        HStack(spacing: 9) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.violet)

            TextField("聊聊…", text: $chatDraft)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.send)
                .focused($isChatInputFocused)
                .onSubmit(sendChatDraft)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Palette.background, in: Capsule())

            Button(action: sendChatDraft) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Palette.violet, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!store.isJoined || chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(!store.isJoined || chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("送出聊天訊息")
        }
    }

    private func sendChatDraft() {
        guard !chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if store.sendChatMessage(chatDraft) {
            chatDraft = ""
        }
    }

    private var microphoneButtonTitle: String {
        if store.isStartingMicrophone { return "正在開啟…" }
        if store.isMicrophoneOn { return "閉麥" }
        if isCurrentUserOnMic { return "開麥" }
        return "申請上麥"
    }

    private var microphoneButtonSymbol: String {
        if store.isMicrophoneOn { return "mic.slash.fill" }
        if isCurrentUserOnMic { return "mic.fill" }
        return "hand.raised.fill"
    }

    private var occupiedSeatCount: Int {
        store.snapshot?.seats.filter { $0.userId != nil }.count ?? room.micCount
    }

    private var isCurrentUserOnMic: Bool {
        store.snapshot?.seats.contains { $0.userId == currentUserId } ?? false
    }

    private var isRoomManager: Bool {
        guard let snapshot = store.snapshot else { return false }
        return snapshot.ownerId == currentUserId || snapshot.admins.contains(currentUserId)
    }

    private func isCurrentUser(_ userId: String) -> Bool {
        userId == currentUserId
    }

    private func avatarURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            if url.pathExtension.lowercased() == "svg" {
                return url.deletingPathExtension().appendingPathExtension("png")
            }
            return url
        }
        let relative = URL(string: trimmed, relativeTo: VoiceServerAPI.baseURL)?.absoluteURL
        guard let relative else { return nil }
        if relative.pathExtension.lowercased() == "svg" {
            return relative.deletingPathExtension().appendingPathExtension("png")
        }
        return relative
    }

    private func leaveRoom() {
        store.leave()
        onLeave()
        dismiss()
    }
}

private struct Palette {
    static let background = Color(red: 0.975, green: 0.965, blue: 0.99)
    static let ink = Color(red: 0.16, green: 0.13, blue: 0.23)
    static let muted = Color(red: 0.49, green: 0.46, blue: 0.56)
    static let violet = Color(red: 0.48, green: 0.31, blue: 0.82)
    static let rose = Color(red: 0.90, green: 0.40, blue: 0.65)
    static let mint = Color(red: 0.28, green: 0.65, blue: 0.58)
    static let amber = Color(red: 0.88, green: 0.58, blue: 0.25)
    static let line = Color(red: 0.91, green: 0.89, blue: 0.94)
}
