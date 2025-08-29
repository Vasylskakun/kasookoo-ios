import Foundation

struct APIConfig {
    static let baseURL = URL(string: "https://voiceai.kasookoo.com/")!
    // Default LiveKit ws URL; override to your environment if backend doesn't return it
    static let defaultLivekitWsUrl = "wss://kasookoosdk-3af68qx7.livekit.cloud"
    static let supportPhoneNumber = "+443333054030" // TODO: set from server/config if needed
}

struct RegisterCallerRequest: Encodable {
    let user_type: String
    let user_id: String
    let device_token: String
    let device_info: [String: AnyCodable]
    let device_type: String = "ios"
}

struct UnregisterCallerRequest: Encodable {
    let user_type: String
    let user_id: String
    let device_token: String
    let device_type: String = "ios"
}

struct SimpleResponse: Codable { let success: Bool; let message: String }

struct CallerTokenRequest: Encodable {
    let room_name: String
    let participant_identity: String
    let participant_identity_name: String
    let participant_identity_type: String
    let caller_user_id: String
    let device_type: String = "ios"
}
struct CalledTokenRequest: Encodable {
    let room_name: String
    let participant_identity: String
    let participant_identity_name: String
    let participant_identity_type: String
    let called_user_id: String
    let device_type: String = "ios"
}
struct TokenResponse: Decodable { let accessToken: String; let wsUrl: String; let roomName: String? }
// Random user fetch (registration)
struct RandomLeadResponse: Decodable {
    let id: String
    let full_name: String
}
struct RandomUserResponse: Decodable {
    let id: String
    let first_name: String
    let last_name: String
}

// SIP call make/end
struct SipMakeCallRequest: Encodable {
    let phone_number: String
    let room_name: String
    let participant_name: String
}
struct SipMakeCallEnvelope: Decodable {
    let success: Bool?
    let message: String?
    let data: SipMakeCallData?
}
struct SipMakeCallData: Decodable {
    let success: Bool?
    let call_details: SipCallDetails?
    let room_token: String?
    let room_name: String?
    let room_session_id: String?
}
struct SipCallDetails: Decodable { let participant_id: String?; let participant_identity: String?; let room_name: String?; let phone_number: String? }
struct SipEndCallRequest: Encodable {
    let participant_identity: String
    let room_name: String
}

final class ApiClient {
    static let shared = ApiClient()
    private init() {}

    // Custom session: temporarily accept server trust for Kasookoo hosts to work around chain issues
    private static let session: URLSession = {
        let delegate = ApiClient.InsecureTrustingDelegate.shared
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }()

    // Hold a strong shared delegate so it's not deallocated
    private final class InsecureTrustingDelegate: NSObject, URLSessionDelegate {
        static let shared = InsecureTrustingDelegate()
        private func handle(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            let host = challenge.protectionSpace.host.lowercased()
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               (host == "voiceai.kasookoo.com" || host.hasSuffix(".kasookoo.com")),
               let trust = challenge.protectionSpace.serverTrust {
                return (.useCredential, URLCredential(trust: trust))
            }
            return (.performDefaultHandling, nil)
        }
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let (d, c) = handle(challenge)
            completionHandler(d, c)
        }
        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let (d, c) = handle(challenge)
            completionHandler(d, c)
        }
    }

    // Generate a unique room name for new calls
    static func generateRoomName() -> String { "sdk-room-" + String(UUID().uuidString.prefix(8)) }

    private func makeRequest<T: Encodable, R: Decodable>(_ path: String, body: T) async throws -> R {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await ApiClient.session.data(for: req)
        #if DEBUG
        if let json = String(data: req.httpBody ?? Data(), encoding: .utf8) {
            print("API → POST \(path) body: \(json)")
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("API ← \(path) resp: \(raw)")
        }
        #endif
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if status >= 300 || status < 0 {
            let bodySnippet = String(data: data, encoding: .utf8) ?? ""
            let message = "HTTP \(status) for \(path)"
            throw NSError(domain: "api", code: status, userInfo: [NSLocalizedDescriptionKey: message, "body": bodySnippet])
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
    private func makeGetRequest<R: Decodable>(_ path: String) async throws -> R {
        var req = URLRequest(url: APIConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await ApiClient.session.data(for: req)
        #if DEBUG
        print("API → GET \(path)")
        if let raw = String(data: data, encoding: .utf8) {
            print("API ← \(path) resp: \(raw)")
        }
        #endif
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if status >= 300 || status < 0 {
            let bodySnippet = String(data: data, encoding: .utf8) ?? ""
            let message = "HTTP \(status) for \(path)"
            throw NSError(domain: "api", code: status, userInfo: [NSLocalizedDescriptionKey: message, "body": bodySnippet])
        }
        return try JSONDecoder().decode(R.self, from: data)
    }

    // Notifications
    func registerToken(_ payload: RegisterCallerRequest) async throws -> SimpleResponse {
        try await makeRequest("api/v1/bot/notifications/register-token", body: payload)
    }
    func unregisterToken(_ payload: UnregisterCallerRequest) async throws -> SimpleResponse {
        try await makeRequest("api/v1/bot/notifications/unregister-token", body: payload)
    }

    // LiveKit token (supports both old and new response shapes)
    func getCallerToken(_ payload: CallerTokenRequest) async throws -> TokenResponse {
        struct Resp: Codable {
            let room_name: String?
            let room_token: String?
            let accessToken: String?
            let wsUrl: String?
        }
        let r: Resp = try await makeRequest("api/v1/bot/sdk/get-caller-livekit-token", body: payload)
        let token = r.room_token ?? r.accessToken ?? ""
        let ws = r.wsUrl ?? APIConfig.defaultLivekitWsUrl
        return TokenResponse(accessToken: token, wsUrl: ws, roomName: r.room_name)
    }
    func getCalledToken(_ payload: CalledTokenRequest) async throws -> TokenResponse {
        struct Resp: Codable {
            let room_name: String?
            let room_token: String?
            let accessToken: String?
            let wsUrl: String?
        }
        let r: Resp = try await makeRequest("api/v1/bot/sdk/get-called-livekit-token", body: payload)
        let token = r.room_token ?? r.accessToken ?? ""
        let ws = r.wsUrl ?? APIConfig.defaultLivekitWsUrl
        return TokenResponse(accessToken: token, wsUrl: ws, roomName: r.room_name)
    }

    // Registration helper endpoints
    func getRandomLead() async throws -> RandomLeadResponse {
        do {
            return try await makeGetRequest("api/v1/bot/random-lead")
        } catch {
            #if targetEnvironment(simulator)
            return RandomLeadResponse(id: "sim-\(UUID().uuidString.prefix(6))", full_name: "Simulator Lead")
            #else
            throw error
            #endif
        }
    }
    func getRandomUser() async throws -> RandomUserResponse {
        do {
            return try await makeGetRequest("api/v1/bot/random-user")
        } catch {
            #if targetEnvironment(simulator)
            return RandomUserResponse(id: "sim-\(UUID().uuidString.prefix(6))", first_name: "Sim", last_name: "Driver")
            #else
            throw error
            #endif
        }
    }

    // SIP call endpoints
    func makeSipCall(_ payload: SipMakeCallRequest) async throws -> TokenResponse {
        let env: SipMakeCallEnvelope = try await makeRequest("api/v1/bot/sdk-sip/calls/make", body: payload)
        let token = env.data?.room_token ?? ""
        let room = env.data?.room_name ?? env.data?.call_details?.room_name ?? payload.room_name
        return TokenResponse(accessToken: token, wsUrl: APIConfig.defaultLivekitWsUrl, roomName: room)
    }
    func endSipCall(_ payload: SipEndCallRequest) async throws -> SimpleResponse {
        try await makeRequest("api/v1/bot/sdk-sip/calls/end", body: payload)
    }
}

// Helper to encode heterogeneous device info
struct AnyCodable: Encodable {
    let value: Any
    init(_ value: Any) { self.value = value }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        default: try container.encode(String(describing: value))
        }
    }
}
