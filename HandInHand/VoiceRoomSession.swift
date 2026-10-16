import Foundation
import Combine
import AVFoundation
import Mediasoup
import WebRTC

struct VoiceRoomSeat: Decodable, Identifiable {
    let index: Int
    let userId: String?
    let producerId: String?
    let muted: Bool

    var id: Int { index }
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
final class VoiceRoomSessionStore: ObservableObject,
    @preconcurrency SendTransportDelegate,
    @preconcurrency ReceiveTransportDelegate,
    @preconcurrency ProducerDelegate,
    @preconcurrency ConsumerDelegate {

    @Published private(set) var snapshot: VoiceRoomSnapshot?
    @Published private(set) var status = "正在連接房間…"
    @Published private(set) var errorMessage: String?
    @Published private(set) var micMessage: String?
    @Published private(set) var isJoined = false
    @Published private(set) var isMicrophoneOn = false
    @Published private(set) var isStartingMicrophone = false

    private let roomId: String
    private let sessionToken: String
    private let currentUserId: String

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var isLeaving = false

    // Native mediasoup/WebRTC media pipeline.
    private let peerConnectionFactory = RTCPeerConnectionFactory()
    private var mediasoupDevice: Device?
    private var sendTransport: SendTransport?
    private var receiveTransport: ReceiveTransport?
    private var audioTrack: RTCAudioTrack?
    private var producer: Producer?
    private var consumers: [String: Consumer] = [:]
    private var consumerOwners: [String: String] = [:]
    private var producerOwners: [String: String] = [:]
    private var pendingProducerOwners: [String: String] = [:]
    private var consumingProducerIds = Set<String>()
    private var consumedProducerIds = Set<String>()
    private var didRequestRtpCapabilities = false
    private var pendingMicStart = false
    private var micRequestPending = false
    private var pendingProduceCallback: ((String?) -> Void)?

    init(roomId: String, sessionToken: String, currentUserId: String) {
        self.roomId = roomId
        self.sessionToken = sessionToken
        self.currentUserId = currentUserId
    }

    func connect() {
        guard socket == nil, !isLeaving else { return }

        status = "正在連接房間…"
        errorMessage = nil
        isLeaving = false

        do {
            try configureAudioSession()
        } catch {
            errorMessage = "無法啟用語音音訊：\(error.localizedDescription)"
        }

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
                await self.readMessages(from: task)
            } catch {
                self.connectionFailed(error, task: task)
            }
        }
    }

    /// Ask for a seat, or starts/stops the real WebRTC microphone if already seated.
    func toggleMicrophone() {
        guard isJoined else {
            micMessage = "尚未加入房間，請稍後再試。"
            return
        }

        if let producer, !producer.closed {
            if producer.paused {
                audioTrack?.isEnabled = true
                producer.resume()
                isMicrophoneOn = true
                send([
                    "type": "mute_mic",
                    "userId": currentUserId,
                    "muted": false
                ])
                micMessage = "麥克風已開啟；你仍可聽見其他人。"
                status = "🎙️ 麥克風已開啟"
            } else {
                producer.pause()
                audioTrack?.isEnabled = false
                isMicrophoneOn = false
                send([
                    "type": "mute_mic",
                    "userId": currentUserId,
                    "muted": true
                ])
                micMessage = "麥克風已關閉；仍可聽見其他人。"
                status = "🔇 麥克風已關閉"
            }
            return
        }

        guard !micRequestPending, !isStartingMicrophone else { return }
        requestMic()
    }

    func requestMic(seatIndex: Int? = nil) {
        guard isJoined else {
            micMessage = "尚未加入房間，請稍後再試。"
            return
        }
        guard !micRequestPending, !isStartingMicrophone else { return }

        micRequestPending = true
        pendingMicStart = false

        var payload: [String: Any] = ["type": "request_mic"]
        if let seatIndex { payload["seatIndex"] = seatIndex }
        send(payload)
        micMessage = "已送出上麥申請；獲准後會啟用麥克風。"
        status = "正在申請上麥…"
    }

    func releaseMic() {
        send(["type": "release_mic"])
        micRequestPending = false
        pendingMicStart = false
        isMicrophoneOn = false
        isStartingMicrophone = false

        producer?.close()
        producer = nil
        audioTrack?.isEnabled = false
        audioTrack = nil

        micMessage = "已下麥"
    }

    func setMuted(_ muted: Bool, userId: String) {
        send([
            "type": "admin_mic_toggle",
            "targetUserId": userId,
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

        if socket != nil {
            send([
                "type": "leave_room",
                "roomId": roomId
            ])
        }

        pendingProduceCallback?(nil)
        pendingProduceCallback = nil
        pendingMicStart = false
        micRequestPending = false
        closeLocalMedia()
        status = "已離開房間"

        let task = socket
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            task?.cancel(with: .goingAway, reason: nil)
            await self?.closeSocket()
        }
    }

    func clearMicMessage() {
        micMessage = nil
    }

    // MARK: WebSocket signaling

    private func send(_ payload: [String: Any]) {
        guard let socket, !isLeaving || payload["type"] as? String == "leave_room" else {
            errorMessage = "房間連線已中斷，請離開後重新進入。"
            return
        }

        let task = socket
        let message = Self.json(payload)
        Task {
            do {
                try await task.send(.string(message))
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
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

                guard
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                    let type = object["type"] as? String
                else { continue }

                switch type {
                case "room_state":
                    guard
                        let raw = object["data"],
                        let stateData = try? JSONSerialization.data(withJSONObject: raw),
                        let state = try? JSONDecoder().decode(VoiceRoomSnapshot.self, from: stateData)
                    else { continue }

                    snapshot = state
                    isJoined = true
                    errorMessage = nil
                    if !didRequestRtpCapabilities {
                        didRequestRtpCapabilities = true
                        send(["type": "get_rtp_capabilities"])
                    }
                    syncMicrophoneStateFromSnapshot()

                case "rtp_capabilities":
                    if let data = object["data"] {
                        handleRTPCapabilities(data)
                    }

                case "transport_created":
                    if let data = object["data"] as? [String: Any] {
                        handleTransportCreated(data)
                    }

                case "transport_connected":
                    status = "語音傳輸已連線"

                case "produced":
                    if let producerId = object["producerId"] as? String {
                        let callback = pendingProduceCallback
                        pendingProduceCallback = nil
                        callback?(producerId)
                    }

                case "new_producer":
                    if let producerId = object["producerId"] as? String,
                       let userId = object["userId"] as? String {
                        queueProducer(producerId: producerId, userId: userId)
                    }

                case "producers":
                    let list = object["producers"] as? [[String: Any]] ?? []
                    for item in list {
                        guard
                            let producerId = item["producerId"] as? String,
                            let userId = item["userId"] as? String
                        else { continue }
                        queueProducer(producerId: producerId, userId: userId)
                    }

                case "consumed":
                    if let data = object["data"] as? [String: Any] {
                        handleConsumed(data)
                    }

                case "consumer_resumed":
                    status = "已開始接收房內音訊"

                case "mic_approved":
                    micRequestPending = false
                    pendingMicStart = true
                    let seat = (object["seatIndex"] as? Int).map { "（第 \($0 + 1) 麥）" } ?? ""
                    micMessage = "已取得上麥許可\(seat)，正在啟用麥克風。"
                    Task { await startMicrophoneIfReady() }

                case "mic_denied":
                    micRequestPending = false
                    pendingMicStart = false
                    micMessage = object["reason"] as? String ?? "上麥申請未通過"
                    status = "上麥申請未通過"

                case "mic_state":
                    if object["userId"] as? String == currentUserId,
                       let muted = object["muted"] as? Bool {
                        setLocalMuted(muted)
                    }

                case "admin_mic_state":
                    if object["userId"] as? String == currentUserId,
                       let muted = object["muted"] as? Bool {
                        setLocalMuted(muted)
                    }

                case "mic_forced_off":
                    producer?.close()
                    producer = nil
                    audioTrack?.isEnabled = false
                    audioTrack = nil
                    isMicrophoneOn = false
                    isStartingMicrophone = false
                    pendingMicStart = false
                    micMessage = "房主已請你下麥。"

                case "user_left":
                    if let userId = object["userId"] as? String {
                        closeConsumers(for: userId)
                    }

                case "room_closed":
                    errorMessage = "房主已關閉房間。"
                    status = "房間已關閉"
                    isJoined = false
                    closeLocalMedia()

                case "error":
                    let message = object["message"] as? String ?? "房間操作失敗"
                    errorMessage = message
                    status = "房間發生錯誤"
                    micRequestPending = false
                    if pendingProduceCallback != nil {
                        let callback = pendingProduceCallback
                        pendingProduceCallback = nil
                        callback?(nil)
                    }
                    if isStartingMicrophone {
                        isStartingMicrophone = false
                        isMicrophoneOn = false
                        pendingMicStart = false
                    }

                default:
                    break
                }
            }
        } catch {
            connectionFailed(error, task: task)
        }
    }

    // MARK: mediasoup setup

    private func handleRTPCapabilities(_ value: Any) {
        guard mediasoupDevice == nil else { return }

        do {
            try configureAudioSession()
            let device = Device(pcFactory: peerConnectionFactory)
            try device.load(with: Self.jsonString(value))
            mediasoupDevice = device

            send(["type": "create_transport", "direction": "send"])
            send(["type": "create_transport", "direction": "recv"])
            status = "正在建立語音傳輸…"
        } catch {
            errorMessage = "初始化語音引擎失敗：\(error.localizedDescription)"
            status = "語音引擎初始化失敗"
        }
    }

    private func handleTransportCreated(_ data: [String: Any]) {
        guard let device = mediasoupDevice,
              let id = data["id"] as? String,
              let direction = data["direction"] as? String,
              let iceParameters = data["iceParameters"],
              let iceCandidates = data["iceCandidates"],
              let dtlsParameters = data["dtlsParameters"] else {
            errorMessage = "伺服器建立語音 Transport 的資料不完整。"
            return
        }

        do {
            let iceParametersJSON = Self.jsonString(iceParameters)
            let iceCandidatesJSON = Self.jsonString(iceCandidates)
            let dtlsParametersJSON = Self.jsonString(dtlsParameters)

            if direction == "send" {
                guard sendTransport == nil else { return }
                let transport = try device.createSendTransport(
                    id: id,
                    iceParameters: iceParametersJSON,
                    iceCandidates: iceCandidatesJSON,
                    dtlsParameters: dtlsParametersJSON,
                    sctpParameters: nil,
                    appData: nil
                )
                transport.delegate = self
                sendTransport = transport
            } else if direction == "recv" {
                guard receiveTransport == nil else { return }
                let transport = try device.createReceiveTransport(
                    id: id,
                    iceParameters: iceParametersJSON,
                    iceCandidates: iceCandidatesJSON,
                    dtlsParameters: dtlsParametersJSON,
                    sctpParameters: nil,
                    appData: nil
                )
                transport.delegate = self
                receiveTransport = transport

                send(["type": "get_producers"])
                processPendingProducers()
            } else {
                return
            }

            if sendTransport != nil, receiveTransport != nil {
                status = "語音傳輸已準備好"
                if pendingMicStart {
                    Task { await startMicrophoneIfReady() }
                }
                processPendingProducers()
            }
        } catch {
            errorMessage = "建立語音傳輸失敗：\(error.localizedDescription)"
            status = "語音傳輸建立失敗"
        }
    }

    // MARK: Microphone controls

    private func startMicrophoneIfReady() async {
        guard pendingMicStart, !isStartingMicrophone else { return }
        guard let transport = sendTransport, mediasoupDevice != nil else {
            status = "正在等待語音傳輸就緒…"
            return
        }

        if let producer, !producer.closed {
            audioTrack?.isEnabled = true
            producer.resume()
            isMicrophoneOn = true
            pendingMicStart = false
            send(["type": "mute_mic", "userId": currentUserId, "muted": false])
            status = "🎙️ 麥克風已開啟"
            return
        }

        isStartingMicrophone = true
        status = "正在啟用麥克風…"

        let permitted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permitted = true
        case .notDetermined:
            permitted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            permitted = false
        }

        guard permitted else {
            isStartingMicrophone = false
            pendingMicStart = false
            micRequestPending = false
            errorMessage = "尚未取得麥克風權限。請在隱私權設定中允許「牽手」使用麥克風。"
            send(["type": "release_mic"])
            return
        }

        do {
            try configureAudioSession()
        } catch {
            isStartingMicrophone = false
            pendingMicStart = false
            micRequestPending = false
            send(["type": "release_mic"])
            errorMessage = "無法啟用音訊：\(error.localizedDescription)"
            return
        }

        let track = peerConnectionFactory.audioTrack(withTrackId: "handinhand-audio-\(UUID().uuidString)")
        track.isEnabled = true
        audioTrack = track
        pendingMicStart = false

        // Native createProducer waits for the server's produced response.
        // Run the synchronous native call off-main so WebSocket receive can continue.
        DispatchQueue.global(qos: .userInitiated).async { [weak self, transport] in
            do {
                let newProducer = try transport.createProducer(
                    for: track,
                    encodings: nil,
                    codecOptions: nil,
                    codec: nil,
                    appData: nil
                )
                DispatchQueue.main.async {
                    guard let self else {
                        newProducer.close()
                        return
                    }
                    self.producer = newProducer
                    newProducer.delegate = self
                    self.isStartingMicrophone = false
                    self.isMicrophoneOn = true
                    self.micRequestPending = false
                    self.status = "🎙️ 麥克風已開啟"
                    self.micMessage = "麥克風已開啟；仍可聽見其他人。"
                    self.send([
                        "type": "mute_mic",
                        "userId": self.currentUserId,
                        "muted": false
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isStartingMicrophone = false
                    self.isMicrophoneOn = false
                    self.micRequestPending = false
                    self.errorMessage = "建立上行音訊失敗：\(error.localizedDescription)"
                    self.status = "麥克風啟用失敗"
                }
            }
        }
    }

    private func setLocalMuted(_ muted: Bool) {
        audioTrack?.isEnabled = !muted
        if muted {
            producer?.pause()
            isMicrophoneOn = false
            status = "🔇 麥克風已關閉"
            micMessage = "麥克風已關閉；仍可聽見其他人。"
        } else {
            producer?.resume()
            isMicrophoneOn = producer != nil
            status = "🎙️ 麥克風已開啟"
            micMessage = "麥克風已開啟。"
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker]
        )
        try audioSession.setActive(true)
    }

    // MARK: Remote audio consumers

    private func queueProducer(producerId: String, userId: String) {
        guard !producerId.isEmpty, userId != currentUserId else { return }
        producerOwners[producerId] = userId

        guard receiveTransport != nil, mediasoupDevice != nil else {
            pendingProducerOwners[producerId] = userId
            return
        }
        requestConsume(producerId: producerId, userId: userId)
    }

    private func processPendingProducers() {
        guard receiveTransport != nil, mediasoupDevice != nil else { return }
        let items = pendingProducerOwners
        pendingProducerOwners.removeAll()

        for (producerId, userId) in items {
            requestConsume(producerId: producerId, userId: userId)
        }
    }

    private func requestConsume(producerId: String, userId: String) {
        guard let receiveTransport, let device = mediasoupDevice else {
            pendingProducerOwners[producerId] = userId
            return
        }
        guard !consumedProducerIds.contains(producerId),
              !consumingProducerIds.contains(producerId) else { return }

        do {
            let capabilities = try device.rtpCapabilities()
            guard let capabilitiesObject = Self.jsonObject(capabilities) else {
                throw VoiceRoomMediaError.invalidJSON("無法讀取本機 RTP Capabilities。")
            }

            consumingProducerIds.insert(producerId)
            producerOwners[producerId] = userId
            send([
                "type": "consume",
                "transportId": receiveTransport.id,
                "producerId": producerId,
                "producerUserId": userId,
                "rtpCapabilities": capabilitiesObject
            ])
        } catch {
            errorMessage = "準備接收房內聲音失敗：\(error.localizedDescription)"
            consumingProducerIds.remove(producerId)
        }
    }

    private func handleConsumed(_ data: [String: Any]) {
        guard let receiveTransport,
              let consumerId = (data["id"] as? String) ?? (data["consumerId"] as? String),
              let producerId = data["producerId"] as? String,
              let rtpParameters = data["rtpParameters"] else {
            errorMessage = "伺服器回傳的音訊 Consumer 資料不完整。"
            return
        }

        guard !consumers.keys.contains(consumerId) else { return }

        do {
            let consumer = try receiveTransport.consume(
                consumerId: consumerId,
                producerId: producerId,
                kind: .audio,
                rtpParameters: Self.jsonString(rtpParameters),
                appData: nil
            )
            consumer.delegate = self
            consumer.track.isEnabled = true
            consumers[consumerId] = consumer
            consumerOwners[consumerId] = producerOwners[producerId] ?? ""

            // Enabled WebRTC audio tracks play through the active AVAudioSession.
            // The server creates Consumers paused, so resume on both sides.
            consumer.resume()
            send([
                "type": "resume_consumer",
                "consumerId": consumerId
            ])
            consumedProducerIds.insert(producerId)
            consumingProducerIds.remove(producerId)
            status = "已接收房內音訊"
        } catch {
            consumingProducerIds.remove(producerId)
            errorMessage = "建立遠端音訊失敗：\(error.localizedDescription)"
        }
    }

    private func closeConsumers(for userId: String) {
        let ids = consumerOwners.filter { $0.value == userId }.map(\.key)
        for id in ids {
            consumers[id]?.close()
            consumers.removeValue(forKey: id)
            consumerOwners.removeValue(forKey: id)
        }

        let producerIds = producerOwners.filter { $0.value == userId }.map(\.key)
        for id in producerIds {
            producerOwners.removeValue(forKey: id)
            pendingProducerOwners.removeValue(forKey: id)
            consumingProducerIds.remove(id)
            consumedProducerIds.remove(id)
        }
    }

    private func syncMicrophoneStateFromSnapshot() {
        guard let seat = snapshot?.seats.first(where: { $0.userId == currentUserId }) else {
            if producer == nil {
                isMicrophoneOn = false
            }
            return
        }

        if seat.producerId != nil {
            isMicrophoneOn = !seat.muted && producer != nil && producer?.paused == false
        }
    }

    // MARK: Delegate callbacks

    nonisolated func onConnect(transport: Transport, dtlsParameters: String) {
        let transportId = transport.id
        Task { @MainActor [weak self] in
            guard let self, let dtlsObject = Self.jsonObject(dtlsParameters) else { return }
            self.send([
                "type": "connect_transport",
                "transportId": transportId,
                "dtlsParameters": dtlsObject
            ])
        }
    }

    nonisolated func onConnectionStateChange(transport: Transport, connectionState: TransportConnectionState) {
        let transportId = transport.id
        let stateText = String(describing: connectionState)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.status = "語音傳輸 \(transportId.prefix(6))：\(stateText)"
        }
    }

    nonisolated func onProduce(
        transport: Transport,
        kind: MediaKind,
        rtpParameters: String,
        appData: String,
        callback: @escaping (String?) -> Void
    ) {
        let transportId = transport.id
        let kindText: String
        switch kind {
        case .audio: kindText = "audio"
        case .video: kindText = "video"
        }

        Task { @MainActor [weak self] in
            guard let self, let parameters = Self.jsonObject(rtpParameters) else {
                callback(nil)
                return
            }

            self.pendingProduceCallback = callback
            self.send([
                "type": "produce",
                "transportId": transportId,
                "kind": kindText,
                "rtpParameters": parameters
            ])
        }
    }

    nonisolated func onProduceData(
        transport: Transport,
        sctpParameters: String,
        label: String,
        protocol dataProtocol: String,
        appData: String,
        callback: @escaping (String?) -> Void
    ) {
        callback(nil)
    }

    nonisolated func onTransportClose(in producer: Producer) {
        let producerId = producer.id
        Task { @MainActor [weak self] in
            guard let self, self.producer?.id == producerId else { return }
            self.producer = nil
            self.audioTrack?.isEnabled = false
            self.audioTrack = nil
            self.isMicrophoneOn = false
            self.isStartingMicrophone = false
        }
    }

    nonisolated func onTransportClose(in consumer: Consumer) {
        let consumerId = consumer.id
        Task { @MainActor [weak self] in
            self?.consumers.removeValue(forKey: consumerId)
            self?.consumerOwners.removeValue(forKey: consumerId)
        }
    }

    private func closeLocalMedia() {
        pendingProduceCallback?(nil)
        pendingProduceCallback = nil

        producer?.close()
        producer = nil
        audioTrack?.isEnabled = false
        audioTrack = nil

        for consumer in consumers.values {
            consumer.close()
        }
        consumers.removeAll()
        consumerOwners.removeAll()
        producerOwners.removeAll()
        pendingProducerOwners.removeAll()
        consumingProducerIds.removeAll()
        consumedProducerIds.removeAll()

        sendTransport?.close()
        receiveTransport?.close()
        sendTransport = nil
        receiveTransport = nil
        mediasoupDevice = nil
        isMicrophoneOn = false
        isStartingMicrophone = false
        pendingMicStart = false
        didRequestRtpCapabilities = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func closeSocket() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isJoined = false
        status = "已離開房間"
    }

    private func connectionFailed(_ error: Error, task: URLSessionWebSocketTask) {
        guard socket === task, !isLeaving else { return }
        socket = nil
        receiveTask = nil
        status = "房間連線中斷"
        errorMessage = error.localizedDescription
        isJoined = false
        closeLocalMedia()
        task.cancel(with: .goingAway, reason: nil)
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func jsonObject(_ string: String) -> Any? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func jsonString(_ value: Any) -> String {
        if let string = value as? String,
           let data = string.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return string
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

private enum VoiceRoomMediaError: LocalizedError {
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let message): return message
        }
    }
}
