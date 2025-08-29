import SwiftUI
import Foundation
import FirebaseMessaging

struct RegistrationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var roleIndex = 0 // 0 customer, 1 driver
    @State private var loading = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    // Headline
                    VStack(spacing: 6) {
                        Text("Create account")
                            .font(.largeTitle.bold())
                            .foregroundColor(.black)
                        Text("Join as a Customer or Driver")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 28)

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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose role").font(.caption).foregroundColor(.secondary)
                            Picker("Role", selection: $roleIndex) {
                                Text("Customer").tag(0)
                                Text("Driver").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .appCard()

                    // Actions
                    Button(loading ? "Registering..." : "Create account") { Task { await register() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(loading)

                    Text("Tip: Push notifications require a real device with FCM.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notification Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func register() async {
        loading = true
        defer { loading = false }
        let userType = roleIndex == 0 ? "customer" : "driver"
        do {
            // 1) Fetch random identity from backend according to role
            let userId: String
            let fullName: String
            if userType == "customer" {
                let lead: RandomLeadResponse = try await ApiClient.shared.getRandomLead()
                userId = lead.id
                fullName = lead.full_name
            } else {
                let user: RandomUserResponse = try await ApiClient.shared.getRandomUser()
                userId = user.id
                fullName = "\(user.first_name) \(user.last_name)"
            }

            // 2) Ensure FCM token exists; attempt direct fetch; on simulator use placeholder
            #if targetEnvironment(simulator)
            let isSimulator = true
            #else
            let isSimulator = false
            #endif
            var fcm = UserDataManager.shared.getDeviceToken()
            if !isSimulator {
                let fetched = try? await Messaging.messaging().token()
                if let tok = fetched, tok.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, tok != "no_fcm_token" {
                    fcm = tok
                    UserDataManager.shared.updateDeviceToken(tok)
                }
            }
            let tokenTrimmed = fcm.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasValidToken = tokenTrimmed.isEmpty == false && tokenTrimmed != "no_fcm_token" && tokenTrimmed != "simulator_fcm_token"
            if tokenTrimmed.isEmpty || tokenTrimmed == "no_fcm_token" {
                fcm = isSimulator ? "simulator_fcm_token" : fcm
            }
            if !isSimulator && !hasValidToken {
                await MainActor.run {
                    alertMessage = "FCM token is unavailable. Please run on a real device with notifications enabled."
                    showAlert = true
                }
                return
            }

            // 3) Save locally
            UserDataManager.shared.saveUserData(userId: userId, userType: userType, fullName: fullName, email: email, phone: "", deviceToken: fcm)

            // 4) Register device token with backend
            // 4) Register device token with backend (also on simulator with placeholder)
            let payload = RegisterCallerRequest(
                user_type: userType,
                user_id: userId,
                device_token: fcm,
                device_info: UserDataManager.shared.deviceInfo()
            )
            if isSimulator || hasValidToken {
                _ = try? await ApiClient.shared.registerToken(payload)
            }

            // 5) Route to main screen
            NotificationCenter.default.post(name: Notification.Name("auth_changed"), object: nil)
        } catch {
            await MainActor.run {
                alertMessage = "Registration failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}
