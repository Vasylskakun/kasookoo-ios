import SwiftUI
import FirebaseMessaging

struct LoginView: View {
    @State private var loading = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                // Icon / Brand
                Image("CallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.top, 28)

                // Titles
                VStack(spacing: 6) {
                    Text("Welcome back 👋")
                        .font(.largeTitle.bold())
                        .foregroundColor(.black)
                    Text("Sign in to continue")
                        .foregroundColor(.gray)
                }

                // Inputs
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill").foregroundColor(.secondary)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .appInputStyle()

                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundColor(.secondary)
                        SecureField("Password", text: $password)
                    }
                    .appInputStyle()
                }
                .appCard()

                // Actions
                VStack(spacing: 12) {
                    Button(loading ? "Logging in..." : "Login") { Task { await login() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(loading)

                    Button("Logout & Reset") { Task { await resetAll() } }
                        .buttonStyle(SecondaryButtonStyle())
                }

                // Footer note
                Text("Notifications require a real device with a valid FCM token.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notification Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func login() async {
        loading = true
        defer { loading = false }
        // Try to obtain a real FCM token. On Simulator, allow bypass with a placeholder and skip backend registration.
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        // Force refresh token by deleting and letting Firebase recreate (device only)
        if !isSimulator { try? await Messaging.messaging().deleteToken() }
        let fetched = isSimulator ? nil : (try? await Messaging.messaging().token())
        let valid = (fetched ?? "no_fcm_token")
        let hasValidToken = valid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && valid != "no_fcm_token"
        if !hasValidToken && !isSimulator {
            await MainActor.run {
                alertMessage = "FCM token is unavailable. Push notifications do not work on the Simulator. Please run on a real device or try again later."
                showAlert = true
            }
            return
        }
        let deviceInfo = UserDataManager.shared.deviceInfo()
        if let userId = UserDataManager.shared.userId, let userType = UserDataManager.shared.userType {
            if hasValidToken {
                let payload = RegisterCallerRequest(user_type: userType, user_id: userId, device_token: valid, device_info: deviceInfo)
                _ = try? await ApiClient.shared.registerToken(payload)
                UserDataManager.shared.updateDeviceToken(valid)
            } else {
                // Simulator path: skip backend registration, store placeholder
                UserDataManager.shared.updateDeviceToken("simulator_fcm_token")
            }
            UserDataManager.shared.clearLoginStatus() // ensure set true below
            UserDataManager.shared.saveUserData(userId: userId, userType: userType, fullName: "User", email: "", phone: "", deviceToken: hasValidToken ? valid : "simulator_fcm_token")
            NotificationCenter.default.post(name: Notification.Name("auth_changed"), object: nil)
        }
    }

    func resetAll() async {
        UserDataManager.shared.clearLoginStatus()
        NotificationCenter.default.post(name: Notification.Name("auth_changed"), object: nil)
    }
}
