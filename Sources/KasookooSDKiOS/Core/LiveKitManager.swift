import Foundation
import AVFoundation
import LiveKit

enum CallType { case customer, driver, support }

typealias CallStateHandler = (String) -> Void

final class LiveKitManager {
    static let shared = LiveKitManager()
    private init() {}

    private(set) var room: Room?
    private(set) var currentCallType: CallType? = nil
    private(set) var currentRoomName: String? = nil

    // Connect and prepare audio for a call
    func connectToRoom(token: String, wsUrl: String, roomName: String, callType: CallType) async throws {
        // Disconnect any existing room first
        if let existing = room { try? await existing.disconnect() }
        // Configure audio session before enabling/publishing microphone to avoid one-way audio
        await configureAudioSessionForCall()

        let newRoom = Room()
        try await newRoom.connect(url: wsUrl, token: token)
        // After connection, observe participant events
        newRoom.add(delegate: self)
        room = newRoom
        currentCallType = callType
        currentRoomName = roomName

        // Post call_started notification to track active room
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("call_started"),
                object: nil,
                userInfo: ["room_name": roomName]
            )
        }

        // Ensure microphone permission and then enable mic
        let granted = await ensureRecordPermission()
        if granted {
            try? await newRoom.localParticipant?.setMicrophone(enabled: true)
        }
    }

    func disconnect() async {
        if let r = room {
            try? await r.disconnect()
        }
        room = nil
        currentCallType = nil
        currentRoomName = nil
        // remove any lingering listeners
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("call_ended"), object: nil)
        }
    }

    func muteAudio() async {
        guard let r = room else { return }
        try? await r.localParticipant?.setMicrophone(enabled: false)
    }

    func unmuteAudio() async {
        guard let r = room else { return }
        try? await r.localParticipant?.setMicrophone(enabled: true)
    }

    // MARK: - Audio
    @MainActor
    private func configureAudioSessionForCall() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use voice chat with speaker by default; avoid A2DP (no microphone) and mixing
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            // ignore on simulator
        }
    }

    private func ensureRecordPermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func routeSpeaker(enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if enabled {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            // ignore on simulator
        }
    }

    var hasRemoteParticipants: Bool {
        guard let r = room else { return false }
        return r.remoteParticipants.isEmpty == false
    }
}

// MARK: - Participant Events
extension LiveKitManager: RoomDelegate {
    func room(_ room: Room, participantDidJoin participant: RemoteParticipant) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("lk_remote_joined"), object: nil)
        }
    }

    func room(_ room: Room, participantDidLeave participant: RemoteParticipant) {
        // If no remaining remote participants, end the call for the local side
        if room.remoteParticipants.isEmpty {
            Task { await self.disconnect() }
        }
    }

    func room(_ room: Room, didUpdateConnectionState state: ConnectionState, oldState: ConnectionState) {
        #if DEBUG
        print("LiveKit state: \(oldState) → \(state)")
        #endif
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("lk_state_update"), object: nil, userInfo: ["state": String(describing: state)])
        }
    }

    func room(_ room: Room, didDisconnect error: Error?) {
        #if DEBUG
        if let error { print("LiveKit didDisconnect: \(error.localizedDescription)") } else { print("LiveKit didDisconnect: normal") }
        #endif
        if let error {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("lk_disconnect_error"), object: nil, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
            }
        }
        Task { await disconnect() }
    }
}
