import SwiftUI
import UIKit

struct CallView: View {
    let isCustomer: Bool
    @State private var isMuted = false
    @State private var speakerOn = true
    @State private var volume: Double = 0.8
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let minSide = min(geo.size.width, geo.size.height)
            let scale = max(0.75, min(1.0, minSide / 390.0))
            let ringBase = max(110, min(180, 140 * scale))
            let avatar = max(92, min(150, 120 * scale))
            let endSize = max(54, min(76, 64 * scale))

            ZStack {
                CallBackground()
                VStack(spacing: 16 * scale) {
                    Spacer(minLength: 12 * scale)
                    Text(inCallTitle())
                        .font(.system(size: 22 * scale, weight: .bold))
                        .foregroundColor(.white)

                    ZStack {
                        PulsingRings(color: .white, baseDiameter: ringBase)
                        Circle().fill(Color.white.opacity(0.12)).frame(width: avatar, height: avatar)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 4))
                            .overlay(
                                Image(systemName: inCallIcon())
                                    .resizable().scaledToFit().frame(width: max(38, min(60, 46 * scale)), height: max(38, min(60, 46 * scale)))
                                    .foregroundColor(.white)
                            )
                    }
                    .padding(.top, 6 * scale)

                    VStack(spacing: 10 * scale) {
                        Toggle("Muted", isOn: $isMuted)
                            .onChange(of: isMuted) { newValue in
                                DispatchQueue.main.async { toggleMute(newValue) }
                            }
                            .tint(AppColors.green)

                        HStack(spacing: 16) {
                            Button {
                                speakerOn.toggle()
                                LiveKitManager.shared.routeSpeaker(enabled: speakerOn)
                            } label: {
                            Image(systemName: speakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: max(14, min(22, 20 * scale)), weight: .bold))
                            }
                        .buttonStyle(RoundButtonStyle(diameter: max(42, min(60, 54 * scale)), fill: .white.opacity(0.12), foreground: .white))

                            Slider(value: $volume, in: 0...1, step: 0.01)
                                .tint(.white)
                        }
                        .onChange(of: volume) { v in
                            DispatchQueue.main.async {
                                speakerOn = v > 0
                                setVolume(v)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button { Task { await endCall() } } label: {
                        Image(systemName: "phone.down.fill").font(.system(size: max(16, min(24, 22 * scale)), weight: .bold))
                    }
                    .buttonStyle(RoundButtonStyle(diameter: endSize, fill: AppColors.red, foreground: .white))
                    .disabled(isEnding)

                    Spacer(minLength: 12 * scale)
                }
            }
            .navigationBarHidden(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ended")).receive(on: DispatchQueue.main)) { _ in
            // Ensure in-call screen goes away on any end event
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lk_disconnect_error")).receive(on: DispatchQueue.main)) { note in
            if let msg = note.userInfo?[NSLocalizedDescriptionKey] as? String {
                // Show a lightweight diagnostic in-call before dismiss
                let alert = UIAlertController(title: "Disconnected", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    dismiss()
                })
                UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    func toggleMute(_ muted: Bool) {
        Task {
            if muted { await LiveKitManager.shared.muteAudio() }
            else { await LiveKitManager.shared.unmuteAudio() }
        }
    }
    func setVolume(_ v: Double) { /* no-op: system output volume not directly settable in iOS */ }
    func endSupportCallIfAny() async {
        // Only attempt SIP end if we initiated a support call.
        guard LiveKitManager.shared.currentCallType == .support,
              let room = LiveKitManager.shared.currentRoomName else { return }
        let participantIdentity = "sip-\(APIConfig.supportPhoneNumber)"
        let req = SipEndCallRequest(participant_identity: participantIdentity, room_name: room)
        _ = try? await ApiClient.shared.endSipCall(req)
    }

    @State private var isEnding = false

    func endCall() async {
        if isEnding { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isEnding = true
        // Notify UI (RingingView) to stop auto-pushing before we disconnect
        NotificationCenter.default.post(name: Notification.Name("call_ending"), object: nil)
        // For support, end on backend before disconnect resets call context
        await endSupportCallIfAny()
        await LiveKitManager.shared.disconnect()
        isEnding = false
    }
}

// MARK: - Labels
extension CallView {
    fileprivate func inCallTitle() -> String {
        if LiveKitManager.shared.currentCallType == .support { return "Support" }
        return isCustomer ? "Driver" : "Customer"
    }
    fileprivate func inCallIcon() -> String {
        if LiveKitManager.shared.currentCallType == .support { return "headphones" }
        return isCustomer ? "car.fill" : "person.fill"
    }
}
