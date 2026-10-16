import Foundation
import Combine

struct VoiceRoomSeat: Decodable, Identifiable {
    let index: Int
    let userId: String?
    let producerId: String?
    let muted: Bool

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index, userId, producerId, muted
    }
}

struct VoiceRoomMember: Decodable, Identifiable {
    let userId: String
    let nickname: String
    let avatarURL: String
    let gender: String
    let role: String
    let micApproved: Bool
    let requestedSeat: Int?
    let seatIndex: Int?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId, nickname, gender, role, micApproved, requestedSeat, seatIndex
        case avatarURL = "avatar_url"
    }
}

struct VoiceRoomPendingMicRequest: Decodable, Identifiable {
    let userId: String
    let nickname: String
    let seatIndex: Int

    var id: String { userId }
}

struct VoiceRoomSnapshot: Decodable {
    let ownerId: String?
    let ownerName: String
    let ownerAvatar: String
    let name: String
    let mode: String
    let userCount: Int
    let admins: [String]
    let locked: Bool
    let seats: [VoiceRoomSeat]
    let users: [VoiceRoomMember]
    let pendingMicRequests: [VoiceRoomPendingMicRequest]

    enum CodingKeys: String, CodingKey {
        case ownerId, ownerName, ownerAvatar, name, mode, userCount, admins, locked, seats, users, pendingMicRequests
    }
}

@MainActor
final class VoiceRoomSessionStore: ObservableObject {
    @Published private(set) var snapshot: VoiceRoomSnapshot?
    @Published private(set) var status = "正在連接房間…"
    @Published private(set) var errorMessage: String?
    @Published private(set) var micMessage: String?
    @Published private(set) var isJoined = false

    private let roomId: String
    private let sessionToken: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var isLeaving = false

    init(roomId: String, sessionToken: String) {
        self.roomId = roomId
        self.sessionToken = sessionToken
    }

    func connect() {
        guard socket == nil else { return }
        status = "正在連接房間…"
        errorMessage = nil

        let task = URLSession.shared.webSocketTask(with: VoiceServerAPI.roomSocketURL)
        socket = task
        task.resume()

        receiveTask = Task { [weak self, weak task] in
            guard let self, let task else { return }
            do {
                try await task.send(.string(Self.json([
                    "type": "join_room",
                    "roomId": self.roomId,
                    "sessionToken": self.sessionToken
                ])))
                await self.receiveMessages(from: task)
            } catch {
                self.fail(error, task: task)
            }
        }
    }

    func requestMic(seatIndex: Int? = nil) {
        guard isJoined else {
            micMessage = "尚未加入房間，請稍後再試。"
            return
        }
        var payload: [String: Any] = ["type": "request_mic"]
        if let seatIndex { payload["seatIndex"] = seatIndex }
        send(payload)
        micMessage = "已送出上麥申請"
    }

    func releaseMic() {
        send(["type": "release_mic"])
        micMessage = "已送出下麥指令"
    }

    func setMuted(_ muted: Bool, userId: String) {
        send([
            "type": "mute_mic",
            "userId": userId,
            "muted": muted
        ])
    }

    func approveMic(_ request: VoiceRoomPendingMicRequest) {
        send([
            "type": "approve_mic",
            "targetUserId": request.userId,
            "seatIndex": request.seatIndex
        ])
    }

    func denyMic(_ request: VoiceRoomPendingMicRequest) {
        send([
            "type": "deny_mic",
            "targetUserId": request.userId
        ])
    }

    func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        guard let socket else {
            closeSocket()
            return
        }

        let task = socket
        Task { [weak self] in
            do {
                try await task.send(.string(Self.json([
                    "type": "leave_room",
                    "roomId": self?.roomId ?? ""
                ])))
                try? await Task.sleep(for: .milliseconds(180))
            } catch {
                // Close locally even if the socket was already lost.
            }
            self?.closeSocket()
        }
    }

    func clearMicMessage() {
        micMessage = nil
    }

    private func send(_ payload: [String: Any]) {
        guard let socket else {
            errorMessage = "房間連線已中斷，請離開後重新進入。"
            return
        }
        let task = socket
        Task { [weak self] in
            do {
                try await task.send(.string(Self.json(payload)))
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func receiveMessages(from task: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .string(let value): data = Data(value.utf8)
                case .data(let value): data = value
                @unknown default: continue
                }

                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                guard let object, let type = object["type"] as? String else { continue }

                switch type {
                case "room_state":
                    guard let raw = object["data"],
                          let stateData = try? JSONSerialization.data(withJSONObject: raw),
                          let state = try? JSONDecoder().decode(VoiceRoomSnapshot.self, from: stateData) else {
                        continue
                    }
                    snapshot = state
                    isJoined = true
                    status = "房間已連線"
                    errorMessage = nil

                case "mic_approved":
                    let seat = (object["seatIndex"] as? Int).map { "（第 \($0 + 1) 麥）" } ?? ""
                    micMessage = "已取得上麥位置\(seat)"

                case "mic_denied":
                    micMessage = object["reason"] as? String ?? "上麥申請未通過"

                case "room_closed":
                    errorMessage = "房主已關閉房間。"
                    status = "房間已關閉"
                    isJoined = false

                case "error":
                    errorMessage = object["message"] as? String ?? "房間操作失敗"
                    status = "房間發生錯誤"

                default:
                    break
                }
            }
        } catch {
            fail(error, task: task)
        }
    }

    private func fail(_ error: Error, task: URLSessionWebSocketTask) {
        guard socket === task, !isLeaving else { return }
        socket = nil
        receiveTask = nil
        status = "房間連線中斷"
        errorMessage = error.localizedDescription
        isJoined = false
        task.cancel(with: .goingAway, reason: nil)
    }

    private func closeSocket() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isJoined = false
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
