import Foundation
import Observation

/// Estado de sesión de la app. Equivale al `AuthContext` + estado de `App.jsx`.
@MainActor
@Observable
final class SessionStore {

    enum Phase: Equatable {
        case launching      // validando el token guardado
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .launching
    private(set) var user: User?

    /// Token de recuperación abierto vía deep link (`finanz://reset?token=...`).
    var pendingResetToken: String?

    init() {
        // La sesión vive durante toda la app, así que el observador no necesita retirarse.
        _ = NotificationCenter.default.addObserver(
            forName: APIClient.unauthorizedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    // MARK: - Ciclo de vida

    /// Valida el JWT guardado al arrancar (equivalente al `useEffect` de `App.jsx`).
    func bootstrap() async {
        guard TokenStore.token != nil else {
            phase = .signedOut
            return
        }
        do {
            user = try await AuthService.currentUser()
            phase = .signedIn
        } catch {
            TokenStore.token = nil
            user = nil
            phase = .signedOut
        }
    }

    func signIn(token: String, user: User) {
        TokenStore.token = token
        self.user = user
        phase = .signedIn
    }

    /// Login vía OAuth2: solo llega el token, hay que pedir el perfil.
    func signIn(withToken token: String) async throws {
        TokenStore.token = token
        do {
            let profile = try await AuthService.currentUser()
            user = profile
            phase = .signedIn
        } catch {
            TokenStore.token = nil
            throw error
        }
    }

    func signOut() {
        TokenStore.token = nil
        user = nil
        phase = .signedOut
    }

    func updateUser(_ user: User) {
        self.user = user
    }

    // MARK: - Deep links

    /// Gestiona `finanz://auth?token=...` y `finanz://reset?token=...`.
    func handle(url: URL) {
        guard url.scheme?.lowercased() == AppConfig.oauthCallbackScheme else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }

        if url.host?.lowercased() == "reset" {
            pendingResetToken = token
        } else {
            Task { try? await signIn(withToken: token) }
        }
    }
}
