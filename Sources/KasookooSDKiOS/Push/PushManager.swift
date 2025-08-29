import Foundation
import UserNotifications

final class PushManager {
    static let shared = PushManager()

    func onFCMTokenRefreshed(token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ignore placeholders or invalid tokens (simulator / missing)
        guard trimmed.isEmpty == false, trimmed != "no_fcm_token", trimmed != "simulator_fcm_token" else { return }
        UserDataManager.shared.updateDeviceToken(trimmed)
        Task { await registerTokenIfLoggedIn(token: trimmed) }
    }

    func registerTokenIfLoggedIn(token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != "no_fcm_token", trimmed != "simulator_fcm_token" else { return }
        guard let userId = UserDataManager.shared.userId,
              let userType = UserDataManager.shared.userType else { return }
        let payload = RegisterCallerRequest(user_type: userType, user_id: userId, device_token: trimmed, device_info: UserDataManager.shared.deviceInfo())
        _ = try? await ApiClient.shared.registerToken(payload)
    }

    func unregisterToken() async {
        guard let userId = UserDataManager.shared.userId,
              let userType = UserDataManager.shared.userType else { return }
        let token = UserDataManager.shared.getDeviceToken()
        let payload = UnregisterCallerRequest(user_type: userType, user_id: userId, device_token: token)
        _ = try? await ApiClient.shared.unregisterToken(payload)
    }

    // MARK: - Incoming call push handling
    // Supports both legacy and new payloads.
    // New payload example (top-level keys may vary by FCM/APNs adapter):
    // data: {
    //   type: "driver_incoming_call" | "customer_incoming_call",
    //   action: "receive_call",
    //   room_name: "sdk-room-xxxx",
    //   participant_identity: "<callee_id>",
    //   participant_identity_name: "<callee_name>",
    //   participant_identity_type: "customer" | "driver",
    //   called_user_id: "<callee_id>"
    // }
    func handle(userInfo: [AnyHashable: Any]) {
        print("🔔 PUSH RECEIVED: userInfo keys = \(userInfo.keys)")
        print("🔔 PUSH RECEIVED: full userInfo = \(userInfo)")
        // Extract custom data either from top-level or nested under "data"
        var custom: [String: Any] = [:]
        if let nested = userInfo["data"] as? [String: Any] {
            custom = nested
        } else if let nestedH = userInfo["data"] as? [String: AnyHashable] {
            custom = nestedH.reduce(into: [:]) { $0[$1.key] = $1.value }
        } else {
            // Fall back to top-level keys
            custom = userInfo.reduce(into: [:]) { $0[String(describing: $1.key)] = $1.value }
        }

        print("📦 PUSH CUSTOM DATA: \(custom)")

        // Infer action from explicit action key, or from type when present
        let rawAction = (custom["action"] as? String) ?? (userInfo["action"] as? String)
        let typeHint = ((custom["type"] as? String) ?? (userInfo["type"] as? String))?.lowercased() ?? ""
        let action = rawAction ?? (typeHint.contains("incoming_call") ? "incoming_call" : (typeHint.contains("cancel") ? "call_cancelled" : ""))

        print("🎯 PUSH ACTION DEBUG: rawAction='\(rawAction ?? "nil")', typeHint='\(typeHint)', inferred action='\(action)'")

        let normalizedAction: String
        switch action.lowercased() {
        case "incoming_call", "receive_call":
            normalizedAction = "incoming_call"
        case "call_cancelled", "end_call", "cancel_call":
            normalizedAction = "call_cancelled"
        default:
            normalizedAction = action
        }

        print("✅ PUSH NORMALIZED ACTION: '\(normalizedAction)'")

        // Build a normalized payload for UI layers
        var payload: [String: Any] = userInfo.reduce(into: [:]) { $0[String(describing: $1.key)] = $1.value }
        // Promote nested data keys to top-level for convenience
        for k in ["room_name", "participant_identity", "participant_identity_name", "participant_identity_type", "type", "called_user_id", "caller_user_id"] {
            if let v = custom[k] { payload[k] = v }
        }
        payload["action"] = normalizedAction

        // Target filtering: only surface calls intended for this logged-in user.
        // If the push includes a called_user_id and it doesn't match our user, ignore.
        let localUserId = UserDataManager.shared.userId
        let localUserType = UserDataManager.shared.userType?.lowercased()
        let calledUserId = (custom["called_user_id"] as? String) ?? (payload["called_user_id"] as? String)
        let callerUserId = (custom["caller_user_id"] as? String) ?? (payload["caller_user_id"] as? String)
        let typeString = ((custom["type"] as? String) ?? (userInfo["type"] as? String))?.lowercased() ?? ""

        print("🔍 PUSH FILTER DEBUG: localUserId='\(localUserId ?? "nil")', localUserType='\(localUserType ?? "nil")'")
        print("🔍 PUSH FILTER DEBUG: calledUserId='\(calledUserId ?? "nil")', callerUserId='\(callerUserId ?? "nil")'")
        print("🔍 PUSH FILTER DEBUG: typeString='\(typeString)', normalizedAction='\(normalizedAction)'")

        // Ignore if explicitly targeted to a different callee
        if let localUserId, let calledUserId, calledUserId.isEmpty == false, calledUserId != localUserId {
            print("❌ PUSH FILTER: Ignoring - called_user_id doesn't match local user")
            return
        }
        // Ignore mirrored notifications sent to the caller themselves
        if normalizedAction == "incoming_call", let localUserId, let callerUserId, callerUserId == localUserId {
            print("❌ PUSH FILTER: Ignoring - mirrored notification to caller")
            return
        }
        // If type hints at role-specific incoming call, ensure our local role matches
        // customer_incoming_call means a customer is calling, so recipient should be driver
        // driver_incoming_call means a driver is calling, so recipient should be customer
        if typeString.contains("customer_incoming_call"), let localUserType, localUserType != "driver" {
            print("❌ PUSH FILTER: Ignoring - customer_incoming_call but user is not driver (should receive customer calls)")
            return
        }
        if typeString.contains("driver_incoming_call"), let localUserType, localUserType != "customer" {
            print("❌ PUSH FILTER: Ignoring - driver_incoming_call but user is not customer (should receive driver calls)")
            return
        }

        print("✅ PUSH FILTER: Passed all filters, proceeding...")

        print("🎯 PUSH ACTION: \(normalizedAction)")

        switch normalizedAction {
        case "incoming_call":
            print("📞 POSTING incoming_call notification with payload: \(payload)")
            NotificationCenter.default.post(name: Notification.Name("incoming_call"), object: nil, userInfo: payload)
        case "call_cancelled":
            print("❌ POSTING call_cancelled notification")
            NotificationCenter.default.post(name: Notification.Name("call_cancelled"), object: nil, userInfo: payload)
        default:
            print("⚪ Ignoring action: \(normalizedAction)")
            break
        }
    }
}
