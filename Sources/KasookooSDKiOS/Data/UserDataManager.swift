import Foundation
import UIKit

final class UserDataManager {
    static let shared = UserDataManager()
    private let d = UserDefaults.standard

    private enum Key: String { case userId, userType, fullName, email, phone, deviceToken, isLoggedIn }

    var userId: String? { d.string(forKey: Key.userId.rawValue) }
    var userType: String? { d.string(forKey: Key.userType.rawValue) }
    var isLoggedIn: Bool { d.bool(forKey: Key.isLoggedIn.rawValue) }
    var fullName: String? { d.string(forKey: Key.fullName.rawValue) }

    func saveUserData(userId: String, userType: String, fullName: String, email: String, phone: String, deviceToken: String) {
        d.set(userId, forKey: Key.userId.rawValue)
        d.set(userType, forKey: Key.userType.rawValue)
        d.set(fullName, forKey: Key.fullName.rawValue)
        d.set(email, forKey: Key.email.rawValue)
        d.set(phone, forKey: Key.phone.rawValue)
        d.set(deviceToken, forKey: Key.deviceToken.rawValue)
        d.set(true, forKey: Key.isLoggedIn.rawValue)
    }

    func updateDeviceToken(_ token: String) { d.set(token, forKey: Key.deviceToken.rawValue) }
    func getDeviceToken() -> String { d.string(forKey: Key.deviceToken.rawValue) ?? "no_fcm_token" }

    func clearLoginStatus() { d.set(false, forKey: Key.isLoggedIn.rawValue) }
    func clearUserData() { for k in [Key.userId, .userType, .fullName, .email, .phone, .deviceToken, .isLoggedIn] { d.removeObject(forKey: k.rawValue) } }

    func deviceInfo() -> [String: AnyCodable] {
        [
            "platform": AnyCodable("iOS"),
            "version": AnyCodable(UIDevice.current.systemVersion),
            "model": AnyCodable(UIDevice.current.model)
        ]
    }
}
