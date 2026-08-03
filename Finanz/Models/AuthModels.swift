import Foundation

/// `UserDto` del backend.
struct User: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let email: String
    let avatarUrl: String?
    let provider: String?   // LOCAL | GOOGLE | GITHUB
}

/// `AuthResponse` del backend: `{ token, user }`.
struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

/// `client = "mobile"` hace que el correo destaque el enlace que abre la app.
struct ForgotPasswordRequest: Encodable {
    let email: String
    var client: String = "mobile"
}

struct ResetPasswordRequest: Encodable {
    let token: String
    let newPassword: String
}

struct UpdateProfileRequest: Encodable {
    let name: String
    let email: String
}

enum OAuthProvider: String, CaseIterable, Identifiable {
    case google
    case github

    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: return "Google"
        case .github: return "GitHub"
        }
    }
}
