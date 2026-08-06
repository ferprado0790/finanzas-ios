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
    case facebook
    /// X. El id se queda como "twitter" porque es el que usan sus URLs.
    case twitter
    /// Ya no se ofrece, pero puede quedar alguna cuenta creada con él.
    case github

    var id: String { rawValue }

    var title: String {
        switch self {
        case .google:   return "Google"
        case .facebook: return "Facebook"
        case .twitter:  return "X"
        case .github:   return "GitHub"
        }
    }

    /// SF Symbol del botón: no hay logos de marca en el catálogo del sistema.
    var symbol: String {
        switch self {
        case .google:   return "globe"
        case .facebook: return "person.2.fill"
        case .twitter:  return "number"
        case .github:   return "chevron.left.forwardslash.chevron.right"
        }
    }
}

/// `AuthProviderDto` — un login social que el backend tiene configurado.
struct AvailableAuthProvider: Decodable, Identifiable {
    let id: String
    let label: String
    /// Si es false, esas cuentas no podrán recuperar la contraseña por email.
    let providesEmail: Bool

    var provider: OAuthProvider? { OAuthProvider(rawValue: id) }
}
