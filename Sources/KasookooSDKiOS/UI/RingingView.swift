import SwiftUI
import UIKit
import AVFoundation

struct RingingView: View {
    let isCustomer: Bool
    // When true, show a dialing/calling UI and wait for other side to join, keep on this screen until joined
    var isDialer: Bool = false
    // Optional room name provided by push for the callee
    var pushRoomName: String? = nil
    // Optional caller display name for incoming sheet
    var pushCallerName: String? = nil
    // Mark if this screen is for Support flow; prevents token calls
    var isSupportCall: Bool = false
    // Auto-accept incoming call by fetching token and connecting immediately
    var autoAccept: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var didAutoStart = false
    @State private var shouldAutoNavigate = true
    @State private var ringingPlayer: AVAudioPlayer?
    @State private var isRinging = false

    var body: some View {
        GeometryReader { geo in
            let minSide = min(geo.size.width, geo.size.height)
            let scale = max(0.75, min(1.0, minSide / 390.0))
            let ringBase = max(110, min(180, 140 * scale))
            let avatar = max(92, min(150, 120 * scale))
            let endSize = max(54, min(76, 64 * scale))

            ZStack {
                CallBackground()
                VStack(spacing: 18 * scale) {
                    Spacer(minLength: 16)
                    Text("Kasookoo SDK")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ZStack {
                        ModernPulsingRings(color: .white, baseDiameter: ringBase)
                        Circle().fill(Color.white.opacity(0.12)).frame(width: avatar, height: avatar)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 4))
                            .overlay(
                                Image(systemName: counterpartIcon())
                                    .resizable().scaledToFit().frame(width: max(38, min(60, 46 * scale)), height: max(38, min(60, 46 * scale)))
                                    .foregroundColor(.white)
                            )
                    }
                    .padding(.top, 8 * scale)

                    VStack(spacing: 6 * scale) {
                        Text((isSupportCall ? "🎧 Support" : (pushCallerName ?? "📞 " + counterpartTitle())))
                            .font(.system(size: 20 * scale, weight: .bold))
                            .foregroundColor(.white)
                        if isSupportCall {
                            Text("Calling Support …")
                                .foregroundColor(.white.opacity(0.85))
                            Text("Waiting for support to accept the call…")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                        } else if isDialer {
                            Text("📱 Calling \(counterpartTitle()) …")
                                .foregroundColor(.white.opacity(0.85))
                            Text("⌛️ Waiting for \(counterpartTitle().lowercased()) to accept the call…")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text("📲 Incoming call from \(pushCallerName ?? counterpartTitle())")
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.top, 4 * scale)

                    Spacer()

                    if isDialer {
                        Button {
                            shouldAutoNavigate = false
                            Task { await LiveKitManager.shared.disconnect() }
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: max(20, min(28, 24 * scale)), weight: .bold))
                        }
                        .buttonStyle(CallButtonStyle(style: .end))
                        .onTapGesture { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    } else {
                        HStack(spacing: max(32, min(64, 48 * scale))) {
                            Button {
                                shouldAutoNavigate = false
                                stopRingingSound() // Stop ringing when declining
                                Task { await LiveKitManager.shared.disconnect() }
                            } label: {
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: max(20, min(28, 24 * scale)), weight: .bold))
                            }
                            .buttonStyle(CallButtonStyle(style: .decline))
                            .onTapGesture { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

                            Button {
                                print("✅ ACCEPT BUTTON: Tapped! Starting call flow...")
                                shouldAutoNavigate = true
                                stopRingingSound() // Stop ringing when accepting
                                Task { await startLiveKit() }
                            } label: {
                                Image(systemName: "phone.fill")
                                    .rotationEffect(.degrees(135))
                                    .font(.system(size: max(20, min(28, 24 * scale)), weight: .bold))
                            }
                            .buttonStyle(CallButtonStyle(style: .accept))
                            .disabled(isLoading)
                            .onTapGesture { UISelectionFeedbackGenerator().selectionChanged() }
                        }
                    }

                    // Navigation is now handled by RootRouterView with fullScreenCover
                    if let error = errorText { Text(error).foregroundColor(.white).font(.footnote) }

                    Spacer(minLength: 16)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            // Debug logging
            print("🔔 RINGING VIEW: Initialized - isDialer=\(isDialer), roomName=\(pushRoomName ?? "nil"), callerName=\(pushCallerName ?? "nil")")

            // Start ringing sound for incoming calls
            startRingingSound()
            print("🔊 RINGING SOUND: Started for incoming call")

            // Auto-start for dialer
            if isSupportCall {
                // Ensure we never trigger caller/called token for support
                // MainView already initiated make-call and connectToRoom.
                let attempts = 120 // ~60s
                for _ in 0..<attempts {
                    if shouldAutoNavigate,
                       let room = LiveKitManager.shared.room, room.remoteParticipants.isEmpty == false {
                        await MainActor.run {
                            // Navigation is handled by RootRouterView via notifications
                            print("📞 REMOTE_JOINED: Navigation handled by RootRouterView")
                        }
                        break
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            } else if isDialer {
                if didAutoStart == false {
                    didAutoStart = true
                    await startLiveKit()
                }
            } else {
                // Callee path: wait for explicit Accept button tap
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ended")).receive(on: DispatchQueue.main)) { _ in
            // Ensure we pop back to MainView when the call ends
            shouldAutoNavigate = false
            // Dismiss self if still visible
            if presentationMode.wrappedValue.isPresented {
                presentationMode.wrappedValue.dismiss()
            } else {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lk_remote_joined")).receive(on: DispatchQueue.main)) { _ in
            // Remote participant joined: navigation is handled by RootRouterView
            print("📞 REMOTE_JOINED: Remote participant joined, navigation handled by RootRouterView")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_cancelled")).receive(on: DispatchQueue.main)) { _ in
            // If caller cancels while we're on ring screen, go back
            shouldAutoNavigate = false
            stopRingingSound() // Stop ringing when call is cancelled
            if presentationMode.wrappedValue.isPresented {
                presentationMode.wrappedValue.dismiss()
            } else {
                dismiss()
            }
        }
        .onDisappear {
            // Clean up ringing sound
            stopRingingSound()
        }
        // Safety net: periodically check for remote participant joined
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if shouldAutoNavigate, LiveKitManager.shared.hasRemoteParticipants {
                print("⏰ TIMER_CHECK: Remote participant detected, navigation handled by RootRouterView")
            }
        }
        // If End Call is tapped elsewhere, stop any auto-navigation
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ending")).receive(on: DispatchQueue.main)) { _ in
            shouldAutoNavigate = false
        }
    }
    
    func startLiveKit() async {
        print("🚀 START_LIVEKIT: Beginning call connection process...")
        isLoading = true
        defer { isLoading = false }
        guard let userId = UserDataManager.shared.userId,
              let userType = UserDataManager.shared.userType else {
            print("❌ START_LIVEKIT: Missing user data")
            errorText = "Missing user"
            return
        }

        print("👤 START_LIVEKIT: User data - ID: \(userId), Type: \(userType)")
        let identityName = UserDataManager.shared.fullName ?? userId
        do {
            // If this is a support call, MainView handled connection; don't fetch any token here.
            if isSupportCall {
                // proceed to polling below
            } else if isDialer {
                // Caller side (driver or customer)
                let req = CallerTokenRequest(
                    room_name: pushRoomName ?? ApiClient.generateRoomName(),
                    participant_identity: userId,
                    participant_identity_name: identityName,
                    participant_identity_type: userType,
                    caller_user_id: userId
                )
                let token = try await ApiClient.shared.getCallerToken(req)
                try await LiveKitManager.shared.connectToRoom(token: token.accessToken, wsUrl: token.wsUrl, roomName: token.roomName ?? (pushRoomName ?? ApiClient.generateRoomName()), callType: (userType.lowercased() == "customer" ? .customer : .driver))
            } else {
                // Callee side: must have room name from push; do not generate a new one
                guard let roomName = pushRoomName else {
                    errorText = "Missing room name from notification"
                    return
                }
                let req = CalledTokenRequest(
                    room_name: roomName,
                    participant_identity: userId,
                    participant_identity_name: identityName,
                    participant_identity_type: userType,
                    called_user_id: userId
                )
                print("📡 START_LIVEKIT: Requesting called token for room: \(roomName)")
                let token = try await ApiClient.shared.getCalledToken(req)
                print("✅ START_LIVEKIT: Token received, connecting to room...")
                try await LiveKitManager.shared.connectToRoom(token: token.accessToken, wsUrl: token.wsUrl, roomName: token.roomName ?? roomName, callType: (userType.lowercased() == "customer" ? .customer : .driver))
            }
            // For callee (incoming calls): navigate immediately after connecting
            // For dialer (outgoing calls): wait for remote participant to join
            if !isDialer {
                // Callee: go to in-call screen immediately
                print("📞 START_LIVEKIT: Incoming call accepted, navigating to call screen...")
                await MainActor.run {
                    // Notify that we've accepted the incoming call - navigation handled by RootRouterView
                    NotificationCenter.default.post(name: Notification.Name("incoming_call_accepted"), object: nil)
                }
            } else {
                // Dialer: handle outgoing calls
                if isSupportCall {
                    // Support calls connect immediately
                    print("📞 SUPPORT_CALL_CONNECTED: Support call connected immediately")
                    await MainActor.run {
                        NotificationCenter.default.post(name: Notification.Name("outgoing_call_connected"), object: nil)
                    }
                } else {
                    // Regular outgoing calls - wait for remote participant to join
                    print("📞 DIALER_WAITING: Waiting for remote participant to join...")
                    let attempts = 120 // up to ~60s for all flows
                    let sleepNs: UInt64 = 500_000_000
                    for _ in 0..<attempts {
                        if shouldAutoNavigate,
                           let room = LiveKitManager.shared.room, room.remoteParticipants.isEmpty == false {
                            await MainActor.run {
                                // Notify RootRouterView that outgoing call connected
                                NotificationCenter.default.post(name: Notification.Name("outgoing_call_connected"), object: nil)
                                print("📞 DIALER_CONNECTED: Remote participant joined, notified RootRouterView")
                            }
                            break
                        }
                        try? await Task.sleep(nanoseconds: sleepNs)
                    }
                }
            }
        } catch {
            // Improve diagnostics for user
            let msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String
            let httpBody = (error as NSError).userInfo["body"] as? String
            if let msg, msg.contains("get-caller-livekit-token") || msg.contains("get-called-livekit-token") {
                if let httpBody, httpBody.isEmpty == false {
                    errorText = "Token API error: \(msg). Details: \(httpBody.prefix(160))…"
                } else {
                    errorText = "Token API error: \(msg)"
                }
            } else if (error as NSError).domain == NSURLErrorDomain {
                errorText = "Network error (\((error as NSError).code)) — check connectivity and server trust."
            } else {
                errorText = "Failed to connect: \(error.localizedDescription)"
            }
        }
    }

    private func startRingingSound() {
        guard !isDialer && !isRinging else { return } // Only ring for incoming calls

        do {
            // Try to load a default system sound or create a simple tone
            // For now, we'll use a simple beep-like sound
            let soundURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/nano/ReceivedMessage.caf")

            if FileManager.default.fileExists(atPath: soundURL.path) {
                ringingPlayer = try AVAudioPlayer(contentsOf: soundURL)
            } else {
                // Fallback: create a simple tone programmatically
                createRingingTone()
            }

            ringingPlayer?.numberOfLoops = -1 // Loop indefinitely
            ringingPlayer?.volume = 0.8
            ringingPlayer?.play()
            isRinging = true
        } catch {
            print("Could not start ringing sound: \(error)")
            // Still show the UI even if sound fails
        }
    }

    private func createRingingTone() {
        // Create a simple ringing tone using system beep
        // This is a fallback when system sounds aren't available
        let soundID: SystemSoundID = 1005 // System sound for incoming call-like notification
        AudioServicesPlaySystemSound(soundID)
        isRinging = true
    }

    private func stopRingingSound() {
        guard isRinging else { return }

        ringingPlayer?.stop()
        ringingPlayer = nil
        isRinging = false

        // Also stop system sound if used
        AudioServicesDisposeSystemSoundID(1005)
    }
}
// MARK: - Labels
extension RingingView {
    fileprivate func counterpartTitle() -> String {
        if isSupportCall { return "Support" }
        return isCustomer ? "Driver" : "Customer"
    }
    fileprivate func counterpartIcon() -> String {
        if isSupportCall { return "headphones" }
        return isCustomer ? "car.fill" : "person.fill"
    }
}
