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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Kasookoo")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await logout() }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(AppColors.error)
                    }
                }
            }
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Welcome Header
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hello!")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(isCustomer ? "Ready to call your driver?" : "Ready to connect with customers?")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()

                                // Status indicator
                                Circle()
                                    .fill(AppColors.success)
                                    .frame(width: 12, height: 12)
                                    .shadow(color: AppColors.success.opacity(0.3), radius: 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // Action Cards
                        VStack(spacing: 20) {
                            if isCustomer {
                                // Customer actions
                                VStack(spacing: 16) {
                                    // Call Driver Card
                                    ModernActionCard(
                                        icon: "car.fill",
                                        iconColor: AppColors.secondary,
                                        title: "Call Your Driver",
                                        subtitle: "Connect with your assigned driver",
                                        buttonText: "Call Driver",
                                        isLoading: false,
                                        action: {
                                            callStatus = nil
                                            showCallDriver = true
                                        }
                                    )

                                    // Support Card
                                    ModernActionCard(
                                        icon: "lifepreserver.fill",
                                        iconColor: AppColors.primary,
                                        title: "Call Support",
                                        subtitle: "Get quick help from our team",
                                        buttonText: placingCall ? "Calling..." : "Call Support",
                                        isLoading: placingCall,
                                        action: {
                                            Task { await callSupport() }
                                        }
                                    )
                                }
                            } else {
                                // Driver actions
                                ModernActionCard(
                                    icon: "person.2.fill",
                                    iconColor: AppColors.success,
                                    title: "Call Customer",
                                    subtitle: "Connect with your assigned customer",
                                    buttonText: "Call Customer",
                                    isLoading: false,
                                    action: {
                                        callStatus = nil
                                        showCallCustomer = true
                                    }
                                )
                            }

                            // Status message
                            if let status = callStatus {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(AppColors.secondary)
                                    Text(status)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(AppColors.surfaceSecondary)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
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
