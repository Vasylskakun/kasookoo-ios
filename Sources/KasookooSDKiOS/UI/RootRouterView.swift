import SwiftUI
import Combine

struct RootRouterView: View {
    @State private var isLoggedIn: Bool = UserDataManager.shared.isLoggedIn
    @State private var hasUserData: Bool = UserDataManager.shared.userId != nil && UserDataManager.shared.userType != nil
    @State private var presentIncoming: Bool = false
    @State private var incomingIsCustomer: Bool = false
    @State private var incomingRoom: String? = nil
    @State private var incomingCallerName: String? = nil

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                if isLoggedIn { MainView(isCustomer: (UserDataManager.shared.userType ?? "customer").lowercased() == "customer") }
                else if hasUserData { LoginView() }
                else { RegistrationView() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("auth_changed")).receive(on: RunLoop.main)) { _ in
            isLoggedIn = UserDataManager.shared.isLoggedIn
            hasUserData = UserDataManager.shared.userId != nil && UserDataManager.shared.userType != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("incoming_call")).receive(on: RunLoop.main)) { note in
            let userInfo = note.userInfo ?? [:]
            let room = (userInfo["room_name"] as? String)

            // Debug logging
            print("📱 INCOMING_CALL received: room=\(room ?? "nil"), userInfo keys: \(userInfo.keys)")

            // Determine UI role to show based on our saved userType, not only payload hints
            let localUserType = (UserDataManager.shared.userType ?? "customer").lowercased()
            // The counterpart role is opposite of local: customer sees driver, driver sees customer
            incomingIsCustomer = (localUserType == "customer")
            incomingRoom = room
            incomingCallerName = (userInfo["participant_identity_name"] as? String)

            // Ensure we have required data
            guard room != nil else {
                print("❌ INCOMING_CALL: Missing room_name")
                return
            }

            print("✅ INCOMING_CALL: Setting up incoming call - room: \(room!), isCustomer: \(incomingIsCustomer)")

            // Use DispatchQueue.main.asyncAfter to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentIncoming = true
                print("📞 INCOMING_CALL: Sheet should now be presented")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_cancelled")).receive(on: RunLoop.main)) { _ in
            // Dismiss incoming sheet if the caller cancelled before we accepted
            presentIncoming = false
            incomingRoom = nil
            incomingCallerName = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ended")).receive(on: RunLoop.main)) { _ in
            // Dismiss any incoming sheet if still presented
            presentIncoming = false
            // Reset any nested navigation by toggling auth flags (no visual change for logged-in)
            isLoggedIn = UserDataManager.shared.isLoggedIn
            hasUserData = UserDataManager.shared.userId != nil && UserDataManager.shared.userType != nil
        }
        // Removed navigate_to_root branch; rely on call_ended to unwind
        .sheet(isPresented: $presentIncoming) {
            NavigationView {
                RingingView(
                    isCustomer: incomingIsCustomer,
                    isDialer: false,
                    pushRoomName: incomingRoom,
                    pushCallerName: incomingCallerName,
                    isSupportCall: false,
                    autoAccept: false
                )
                .navigationBarHidden(true)
            }
        }
    }
}
