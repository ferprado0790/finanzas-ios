import AuthenticationServices
import UIKit

/// Envoltura async/await de `ASWebAuthenticationSession` para el login OAuth2.
///
/// El backend termina el flujo redirigiendo a `${FRONTEND_URL}?token=<jwt>`; si
/// se arranca con `FRONTEND_URL=finanz://auth`, esa redirección la captura esta
/// sesión y no llega a abrirse ningún navegador externo.
final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {

    static let shared = WebAuthenticator()

    /// Error que indica que la persona cerró el navegador; no debe mostrarse como fallo.
    struct Cancelled: Error {}

    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: Cancelled())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: Cancelled())
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            if !session.start() {
                continuation.resume(throwing: APIError.transport("No se pudo abrir el navegador de autenticación."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
