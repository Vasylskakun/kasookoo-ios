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
    @State private var showCallView: Bool = false // Control call view presentation
    @State private var showOutgoingCall: Bool = false // Control outgoing call sheet
    @State private var outgoingIsCustomer: Bool = false
    @State private var outgoingIsSupportCall: Bool = false

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
            // Dismiss any sheets if still presented
            presentIncoming = false
            showOutgoingCall = false
            showCallView = false
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
            // Call was accepted, dismiss the ringing screen and show the call screen
            print("✅ INCOMING_CALL_ACCEPTED: Dismissing ringing screen and showing call screen")
            presentIncoming = false
            showCallView = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("outgoing_call_initiated")).receive(on: RunLoop.main)) { note in
            // Outgoing call initiated from MainView
            let userInfo = note.userInfo ?? [:]
            outgoingIsCustomer = (userInfo["isCustomer"] as? Bool) ?? false
            outgoingIsSupportCall = (userInfo["isSupportCall"] as? Bool) ?? false

            print("📞 OUTGOING_CALL_INITIATED: isCustomer=\(outgoingIsCustomer), isSupport=\(outgoingIsSupportCall)")
            showOutgoingCall = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("outgoing_call_connected")).receive(on: RunLoop.main)) { _ in
            // Outgoing call connected, dismiss ringing screen and show call screen
            print("📞 OUTGOING_CALL_CONNECTED: Dismissing ringing screen and showing call screen")
            showOutgoingCall = false
            showCallView = true
        }
        // Incoming call sheet
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
        // Outgoing call sheet
        .sheet(isPresented: $showOutgoingCall, onDismiss: {
            print("📞 OUTGOING_SHEET_DISMISSED: Outgoing call sheet was dismissed")
        }) {
            NavigationView {
                RingingView(
                    isCustomer: outgoingIsCustomer,
                    isDialer: true,
                    pushRoomName: nil,
                    pushCallerName: nil,
                    isSupportCall: outgoingIsSupportCall,
                    autoAccept: false
                )
                .navigationBarHidden(true)
            }
        }
        // Call view as full screen cover
        .fullScreenCover(isPresented: $showCallView, onDismiss: {
            print("📞 CALL_VIEW_DISMISSED: Call view was dismissed")
        }) {
            CallView(isCustomer: incomingIsCustomer)
        }
    }
}
