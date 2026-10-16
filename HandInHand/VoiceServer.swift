import Foundation
import Combine

enum VoiceServerAPI {
    static let baseURL = URL(string: "https://voice.all-decrypt.com")!
    static let roomSocketURL = URL(string: "wss://voice.all-decrypt.com/socket")!
}

struct VoiceServerUser: Decodable {
    let userId: String
    let provider: String
    let email: String
    let nickname: String
    let avatar: String
    let gender: String
    let profileCompleted: Bool
    let birthDate: String?

    var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let emailName = email.split(separator: "@").first { return String(emailName) }
        return provider == "apple" ? "Apple 使用者" : "Google 使用者"
    }
}

struct GoogleVerifyResponse: Decodable {
    let ok: Bool
    let needsProfile: Bool
    let isNew: Bool?
    let sessionToken: String
    let user: VoiceServerUser
}

struct ProfileCompleteResponse: Decodable {
    let ok: Bool
    let user: VoiceServerUser
}

private struct VoiceServerErrorResponse: Decodable {
    let error: String?
}

enum VoiceServerAPIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "伺服器回傳的資料格式不正確。"
        case .server(let message):
            return message
        }
    }
}

final class VoiceServerAPIClient {
    static let shared = VoiceServerAPIClient()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func verifyGoogle(idToken: String) async throws -> GoogleVerifyResponse {
        var request = URLRequest(url: URL(string: "/auth/google/verify", relativeTo: VoiceServerAPI.baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["credential": idToken])

        let data = try await send(request)
        return try JSONDecoder().decode(GoogleVerifyResponse.self, from: data)
    }

    func completeProfile(
        sessionToken: String,
        nickname: String,
        gender: String,
        birthDate: String
    ) async throws -> ProfileCompleteResponse {
        var request = URLRequest(url: URL(string: "/api/profile/complete", relativeTo: VoiceServerAPI.baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "nickname": nickname,
            "gender": gender,
            "birthDate": birthDate
        ])

        let data = try await send(request)
        return try JSONDecoder().decode(ProfileCompleteResponse.self, from: data)
    }

    func logout(sessionToken: String) async {
        guard !sessionToken.isEmpty else { return }
        var request = URLRequest(url: URL(string: "/auth/logout", relativeTo: VoiceServerAPI.baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        _ = try? await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceServerAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(VoiceServerErrorResponse.self, from: data)
            throw VoiceServerAPIError.server(
                serverError?.error ?? "伺服器連線失敗（HTTP \(httpResponse.statusCode)）。"
            )
        }

        return data
    }
}

struct PendingProfile: Identifiable {
    var id: String { serverUser.userId }
    let sessionToken: String
    let serverUser: VoiceServerUser
}

struct VoiceRoom: Decodable, Identifiable {
    let roomId: String
    let ownerId: String?
    let ownerName: String
    let ownerAvatar: String
    let coverImage: String?
    let name: String
    let mode: String
    let userCount: Int
    let micCount: Int
    let locked: Bool

    var id: String { roomId }

    var displayImageURL: URL? {
        for rawValue in [coverImage, Optional(ownerAvatar)].compactMap({ $0 }) {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            let url: URL?
            if let absolute = URL(string: value), let scheme = absolute.scheme, !scheme.isEmpty {
                url = absolute
            } else {
                url = URL(string: value, relativeTo: VoiceServerAPI.baseURL)?.absoluteURL
            }

            guard let url else { continue }
            // SwiftUI AsyncImage doesn't decode SVG. Use the styled fallback for SVG defaults.
            if url.pathExtension.lowercased() == "svg" { continue }
            return url
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case roomId, ownerId, ownerName, ownerAvatar, coverImage, name, mode, userCount, micCount, locked
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try values.decode(String.self, forKey: .roomId)
        ownerId = try values.decodeIfPresent(String.self, forKey: .ownerId)
        ownerName = try values.decodeIfPresent(String.self, forKey: .ownerName) ?? "房主"
        ownerAvatar = try values.decodeIfPresent(String.self, forKey: .ownerAvatar) ?? ""
        coverImage = try values.decodeIfPresent(String.self, forKey: .coverImage)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "語音房"
        mode = try values.decodeIfPresent(String.self, forKey: .mode) ?? "multi"
        userCount = try values.decodeIfPresent(Int.self, forKey: .userCount) ?? 0
        micCount = try values.decodeIfPresent(Int.self, forKey: .micCount) ?? 0
        locked = try values.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }
}

private struct RoomListEnvelope: Decodable {
    let type: String
    let rooms: [VoiceRoom]?
    let message: String?
}

enum VoiceRoomConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: return "尚未連線"
        case .connecting: return "正在連接牽手語音伺服器…"
        case .connected: return "已連接牽手語音伺服器"
        case .failed(let message): return "連線失敗：\(message)"
        }
    }
}

@MainActor
final class VoiceRoomStore: ObservableObject {
    @Published private(set) var rooms: [VoiceRoom] = []
    @Published private(set) var connectionState: VoiceRoomConnectionState = .disconnected

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    func connect() {
        if socket != nil {
            refresh()
            return
        }

        connectionState = .connecting
        let task = URLSession.shared.webSocketTask(with: VoiceServerAPI.roomSocketURL)
        socket = task
        task.resume()

        receiveTask = Task { [weak self, weak task] in
            guard let self, let task else { return }
            do {
                try await task.send(.string(#"{"type":"list_rooms"}"#))
                await self.readMessages(from: task)
            } catch {
                self.connectionFailed(error, task: task)
            }
        }
    }

    func refresh() {
        guard let socket else {
            connect()
            return
        }

        let task = socket
        Task { [weak self] in
            do {
                try await task.send(.string(#"{"type":"list_rooms"}"#))
            } catch {
                self?.connectionFailed(error, task: task)
            }
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        connectionState = .disconnected
    }

    private func readMessages(from task: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let bytes):
                    data = bytes
                @unknown default:
                    continue
                }

                guard let envelope = try? JSONDecoder().decode(RoomListEnvelope.self, from: data) else {
                    continue
                }

                if envelope.type == "room_list" {
                    rooms = envelope.rooms ?? []
                    connectionState = .connected
                } else if envelope.type == "error", let message = envelope.message {
                    connectionState = .failed(message)
                }
            }
        } catch {
            connectionFailed(error, task: task)
        }
    }

    private func connectionFailed(_ error: Error, task: URLSessionWebSocketTask) {
        guard socket === task else { return }
        socket = nil
        receiveTask = nil
        connectionState = .failed(error.localizedDescription)
        task.cancel(with: .goingAway, reason: nil)
    }

}
