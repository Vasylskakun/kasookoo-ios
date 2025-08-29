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

            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 24) {
                        // Logo/Brand
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryLight.opacity(0.3), AppColors.secondaryLight.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: AppColors.primary.opacity(0.2), radius: 20, x: 0, y: 10)

                            Image("CallIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.top, 20)

                        // Welcome Text
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)

                            Text("Sign in to your account")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Input Form
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(AppColors.primary.opacity(0.7))
                                        .frame(width: 20)

                                    TextField("Enter your email", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .modernInputStyle()
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(AppColors.primary.opacity(0.7))
                                        .frame(width: 20)

                                    SecureField("Enter your password", text: $password)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .modernInputStyle()
                            }
                        }
                        .modernCard(padding: 24)
                    }

                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            Task { await login() }
                        }) {
                            HStack {
                                if loading {
                                    LoadingSpinner()
                                        .frame(width: 20, height: 20)
                                }
                                Text(loading ? "Signing In..." : "Sign In")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: loading))
                        .disabled(loading)

                        Button(action: {
                            Task { await resetAll() }
                        }) {
                            Text("Reset Account")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    // Footer
                    VStack(spacing: 12) {
                        Text("💡 Tip")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.secondary)

                        Text("Push notifications require a real device with a valid FCM token for full functionality.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
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
