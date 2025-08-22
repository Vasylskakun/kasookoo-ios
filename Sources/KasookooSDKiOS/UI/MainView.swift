import SwiftUI

struct MainView: View {
    let isCustomer: Bool
    @State private var navigating = false
    @State private var placingCall = false
    @State private var callStatus: String? = nil
    @State private var showSupportCalling = false
    @State private var showCallDriver = false
    @State private var showCallCustomer = false

    var body: some View {
        NavigationView { mainContent }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("Kasookoo").foregroundColor(.white) } }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ended")).receive(on: DispatchQueue.main)) { _ in
            // Ensure any active calling screen is dismissed
            showSupportCalling = false
            showCallDriver = false
            showCallCustomer = false
            navigating = false
            callStatus = nil
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geo in
            let base: CGFloat = 390
            let scale = min(1.0, min(geo.size.width, geo.size.height) / base)

            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        // (moved hidden navigator out of ScrollView to avoid nav bar conflicts)
                        // Header bar
                        HStack {
                            Text("📞 Kasookoo SDK")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.7)
                            Spacer()
                        }
                        .padding(.horizontal, 10 * scale)
                        .padding(.vertical, 8 * scale)
                        .background(AppColors.greenDark.opacity(0.25))
                        .cornerRadius(10 * scale)

                        // Action cards
                        VStack(alignment: .leading, spacing: 12) {
                            if isCustomer {
                                // Call Driver card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "car.fill").foregroundColor(.white)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("🚗 Call Your Driver").foregroundColor(.white).font(.callout.weight(.semibold))
                                            Text("Connect with your assigned driver").foregroundColor(.white.opacity(0.75)).font(.caption2)
                                        }
                                    }
                                    Button("Call Driver Now") {
                                        callStatus = nil
                                        showCallDriver = true
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                                .appCard()

                                // Call Support card
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lifepreserver.fill").foregroundColor(.white)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("🎧 Call Support").foregroundColor(.white).font(.callout.weight(.semibold))
                                            Text("Get quick help from our team").foregroundColor(.white.opacity(0.75)).font(.caption2)
                                        }
                                    }
                                    Button(placingCall ? "Calling..." : "Call Support") { Task { await callSupport() } }
                                        .buttonStyle(PrimaryButtonStyle())
                                        .disabled(placingCall)
                                }
                                .appCard()
                            } else {
                                // Driver screen: Call Customer card only
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.2.fill").foregroundColor(.white)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("👤 Call Customer").foregroundColor(.white).font(.callout.weight(.semibold))
                                            Text("Connect with your assigned user").foregroundColor(.white.opacity(0.75)).font(.caption2)
                                        }
                                    }
                                    Button("Call Customer") {
                                        callStatus = nil
                                        showCallCustomer = true
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                                .appCard()
                            }

                            if let callStatus { Text(callStatus).font(.footnote).foregroundColor(.white.opacity(0.9)).minimumScaleFactor(0.7) }
                        }

                        Button("Logout") { Task { await logout() } }
                            .buttonStyle(DestructiveButtonStyle())
                    }
                    .padding(14 * scale)
                    .scaleEffect(scale, anchor: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                // Hidden navigators for programmatic control
                NavigationLink(destination: RingingView(isCustomer: true, isDialer: true, pushRoomName: nil, isSupportCall: true).navigationBarHidden(true), isActive: $showSupportCalling) { EmptyView() }
                NavigationLink(destination: RingingView(isCustomer: true, isDialer: true, pushRoomName: nil, isSupportCall: false).navigationBarHidden(true), isActive: $showCallDriver) { EmptyView() }
                NavigationLink(destination: RingingView(isCustomer: false, isDialer: true, pushRoomName: nil, isSupportCall: false).navigationBarHidden(true), isActive: $showCallCustomer) { EmptyView() }
            }
        }
    }

    func logout() async {
        await PushManager.shared.unregisterToken()
        UserDataManager.shared.clearLoginStatus()
        NotificationCenter.default.post(name: Notification.Name("auth_changed"), object: nil)
    }

    func callSupport() async {
        placingCall = true
        defer { placingCall = false }
        // Build request from local user context
        let participantName = UserDataManager.shared.fullName ?? (UserDataManager.shared.userId ?? "ios-user")
        let generatedRoom = ApiClient.generateRoomName()
        let req = SipMakeCallRequest(phone_number: APIConfig.supportPhoneNumber,
                                     room_name: generatedRoom,
                                     participant_name: participantName)
        do {
            // Show calling screen immediately
            showSupportCalling = true
            callStatus = "Starting call..."
            // Backend returns TokenResponse; connect to room
            let res = try await ApiClient.shared.makeSipCall(req)
            callStatus = "Connecting..."
            try await LiveKitManager.shared.connectToRoom(token: res.accessToken, wsUrl: res.wsUrl, roomName: res.roomName ?? generatedRoom, callType: .support)
        } catch {
            callStatus = "Failed to start support call"
            // If we failed before entering the room, back out of the calling screen
            showSupportCalling = false
        }
    }
}
