import SwiftUI
import UIKit

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
    @State private var connect = false
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var didAutoStart = false
    @State private var shouldAutoNavigate = true

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
                        PulsingRings(color: .white, baseDiameter: ringBase)
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
                            Image(systemName: "phone.down.fill").font(.system(size: max(16, min(24, 22 * scale)), weight: .bold))
                        }
                        .buttonStyle(RoundButtonStyle(diameter: endSize, fill: AppColors.red, foreground: .white))
                        .onTapGesture { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    } else {
                        HStack(spacing: max(24, min(48, 36 * scale))) {
                            Button {
                                shouldAutoNavigate = false
                                connect = false
                                Task { await LiveKitManager.shared.disconnect() }
                            } label: {
                                Image(systemName: "phone.down.fill").font(.system(size: max(16, min(24, 20 * scale)), weight: .bold))
                            }
                            .buttonStyle(RoundButtonStyle(diameter: max(52, min(72, 60 * scale)), fill: AppColors.red, foreground: .white))
                            .onTapGesture { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

                            Button {
                                shouldAutoNavigate = true
                                Task { await startLiveKit() }
                            } label: {
                                Image(systemName: "phone.fill").rotationEffect(.degrees(135)).font(.system(size: max(16, min(24, 20 * scale)), weight: .bold))
                            }
                            .buttonStyle(RoundButtonStyle(diameter: max(52, min(72, 60 * scale)), fill: AppColors.green, foreground: .white))
                            .disabled(isLoading)
                            .onTapGesture { UISelectionFeedbackGenerator().selectionChanged() }
                        }
                    }

                    NavigationLink(destination: CallView(isCustomer: isCustomer), isActive: $connect) { EmptyView() }
                    if let error = errorText { Text(error).foregroundColor(.white).font(.footnote) }

                    Spacer(minLength: 16)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            // Auto-start for dialer
            if isSupportCall {
                // Ensure we never trigger caller/called token for support
                // MainView already initiated make-call and connectToRoom.
                let attempts = 120 // ~60s
                for _ in 0..<attempts {
                    if shouldAutoNavigate,
                       let room = LiveKitManager.shared.room, room.remoteParticipants.isEmpty == false {
                        await MainActor.run { connect = true }
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
            connect = false
            // Dismiss self if still visible
            if presentationMode.wrappedValue.isPresented {
                presentationMode.wrappedValue.dismiss()
            } else {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lk_remote_joined")).receive(on: DispatchQueue.main)) { _ in
            // Remote participant joined: go to in-call immediately
            if shouldAutoNavigate { connect = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_cancelled")).receive(on: DispatchQueue.main)) { _ in
            // If caller cancels while we're on ring screen, go back
            shouldAutoNavigate = false
            connect = false
            if presentationMode.wrappedValue.isPresented {
                presentationMode.wrappedValue.dismiss()
            } else {
                dismiss()
            }
        }
        .onDisappear {
            // Ensure we don't leave the ring view hanging as active
            connect = false
        }
        // Safety net: periodically check for remote participant joined
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if shouldAutoNavigate, connect == false, LiveKitManager.shared.hasRemoteParticipants {
                connect = true
            }
        }
        // If End Call is tapped elsewhere, stop any auto-navigation
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ending")).receive(on: DispatchQueue.main)) { _ in
            shouldAutoNavigate = false
            connect = false
        }
    }
    
    func startLiveKit() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = UserDataManager.shared.userId,
              let userType = UserDataManager.shared.userType else {
            errorText = "Missing user"
            return
        }
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
                let token = try await ApiClient.shared.getCalledToken(req)
                try await LiveKitManager.shared.connectToRoom(token: token.accessToken, wsUrl: token.wsUrl, roomName: token.roomName ?? roomName, callType: (userType.lowercased() == "customer" ? .customer : .driver))
            }
            // For callee (incoming calls): navigate immediately after connecting
            // For dialer (outgoing calls): wait for remote participant to join
            if !isDialer {
                // Callee: go to in-call screen immediately
                await MainActor.run { connect = true }
            } else {
                // Dialer: wait for remote participant to join
                let attempts = 120 // up to ~60s for all flows
                let sleepNs: UInt64 = 500_000_000
                for _ in 0..<attempts {
                    if shouldAutoNavigate,
                       let room = LiveKitManager.shared.room, room.remoteParticipants.isEmpty == false {
                        await MainActor.run { connect = true }
                        break
                    }
                    try? await Task.sleep(nanoseconds: sleepNs)
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
