import SwiftUI
import Combine

struct RootRouterView: View {
    @State private var isLoggedIn: Bool = UserDataManager.shared.isLoggedIn
    @State private var hasUserData: Bool = UserDataManager.shared.userId != nil && UserDataManager.shared.userType != nil
    @State private var presentIncoming: Bool = false
    @State private var incomingIsCustomer: Bool = false
    @State private var incomingRoom: String? = nil
    @State private var incomingCallerName: String? = nil
    @State private var activeRoomName: String? = nil // Track current active call room

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
            print("📱 INCOMING_CALL received: room=\(room ?? "nil"), activeRoom=\(activeRoomName ?? "nil")")

            // Ensure we have required data
            guard let room = room, !room.isEmpty else {
                print("❌ INCOMING_CALL: Missing room_name")
                return
            }

            // If we're already in a call with the same room, ignore this notification
            if let activeRoom = activeRoomName, activeRoom == room {
                print("⚠️ INCOMING_CALL: Ignoring - already in call with same room: \(room)")
                return
            }

            // If we're already in any call, ignore incoming calls (prevent call waiting)
            if activeRoomName != nil {
                print("⚠️ INCOMING_CALL: Ignoring - already in another call: \(activeRoomName!)")
                return
            }

            print("✅ INCOMING_CALL: Processing new call - room: \(room)")

            // Determine UI role to show based on our saved userType, not only payload hints
            let localUserType = (UserDataManager.shared.userType ?? "customer").lowercased()
            // The counterpart role is opposite of local: customer sees driver, driver sees customer
            incomingIsCustomer = (localUserType == "customer")
            incomingRoom = room
            incomingCallerName = (userInfo["participant_identity_name"] as? String)

            // Use DispatchQueue.main.asyncAfter to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                presentIncoming = true
                print("📞 INCOMING_CALL: Sheet should now be presented for room: \(room)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_cancelled")).receive(on: RunLoop.main)) { _ in
            // Dismiss incoming sheet if the caller cancelled before we accepted
            print("❌ CALL_CANCELLED: Dismissing incoming call sheet")
            presentIncoming = false
            incomingRoom = nil
            incomingCallerName = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_ended")).receive(on: RunLoop.main)) { _ in
            print("🏁 CALL_ENDED: Clearing active room and resetting UI")
            // Clear the active room when call ends
            activeRoomName = nil
            // Dismiss any incoming sheet if still presented
            presentIncoming = false
            // Reset any nested navigation by toggling auth flags (no visual change for logged-in)
            isLoggedIn = UserDataManager.shared.isLoggedIn
            hasUserData = UserDataManager.shared.userId != nil && UserDataManager.shared.userType != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("call_started")).receive(on: RunLoop.main)) { note in
            // Track the active room when a call starts
            if let roomName = note.userInfo?["room_name"] as? String {
                print("📞 CALL_STARTED: Setting active room to: \(roomName)")
                activeRoomName = roomName
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("incoming_call_accepted")).receive(on: RunLoop.main)) { _ in
            // Dismiss the incoming call sheet when call is accepted
            print("✅ INCOMING_CALL_ACCEPTED: Dismissing incoming call sheet")
            presentIncoming = false
        }
        // Removed navigate_to_root branch; rely on call_ended to unwind
        .sheet(isPresented: $presentIncoming, onDismiss: {
            print("📱 SHEET_DISMISSED: Incoming call sheet was dismissed")
        }) {
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
