import Foundation

/// Equivalente nativo de `authService.js`.
enum AuthService {

    private static var client: APIClient { .shared }

    static func login(email: String, password: String) async throws -> AuthResponse {
        let endpoint = try Endpoint.json("/auth/login",
                                         method: .post,
                                         body: LoginRequest(email: email, password: password),
                                         requiresAuth: false)
        return try await client.send(endpoint)
    }

    static func register(name: String, email: String, password: String) async throws -> AuthResponse {
        let endpoint = try Endpoint.json("/auth/register",
                                         method: .post,
                                         body: RegisterRequest(name: name, email: email, password: password),
                                         requiresAuth: false)
        return try await client.send(endpoint)
    }

    /// Valida el JWT guardado y devuelve el usuario (`GET /auth/me`).
    static func currentUser() async throws -> User {
        try await client.send(Endpoint(path: "/auth/me"))
    }

    /// `PATCH /auth/me` — devuelve un token nuevo porque el email puede cambiar.
    static func updateProfile(name: String, email: String) async throws -> AuthResponse {
        let endpoint = try Endpoint.json("/auth/me",
                                         method: .patch,
                                         body: UpdateProfileRequest(name: name, email: email))
        return try await client.send(endpoint)
    }

    static func forgotPassword(email: String) async throws {
        let endpoint = try Endpoint.json("/auth/forgot-password",
                                         method: .post,
                                         body: ForgotPasswordRequest(email: email),
                                         requiresAuth: false)
        try await client.sendIgnoringResponse(endpoint)
    }

    static func resetPassword(token: String, newPassword: String) async throws {
        let endpoint = try Endpoint.json("/auth/reset-password",
                                         method: .post,
                                         body: ResetPasswordRequest(token: token, newPassword: newPassword),
                                         requiresAuth: false)
        try await client.sendIgnoringResponse(endpoint)
    }

    /// URL que abre el flujo OAuth2 del backend en `ASWebAuthenticationSession`.
    ///
    /// `client=mobile` le dice al backend que, al terminar, redirija al deep
    /// link `finanz://auth` en vez de a la web.
    static func oauthURL(for provider: OAuthProvider) -> URL {
        let base = AppConfig.baseURL
            .appendingPathComponent("oauth2")
            .appendingPathComponent("authorization")
            .appendingPathComponent(provider.rawValue)

        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        components.queryItems = [URLQueryItem(name: "client", value: "mobile")]
        return components.url ?? base
    }
}
