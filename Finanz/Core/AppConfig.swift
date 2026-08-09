import Foundation

/// Configuración global de la app.
///
/// La URL base se puede cambiar en tiempo de ejecución desde Ajustes, lo que
/// permite apuntar a un backend local mientras se desarrolla sin recompilar.
enum AppConfig {

    /// Backend público, servido por el túnel de Cloudflare con HTTPS. Funciona
    /// igual en el simulador, en un iPhone por WiFi y con datos móviles.
    static let defaultBaseURL = "https://finanz.kerbero.uk/api"

    /// Esquema URL que debe devolver el backend tras el login OAuth2.
    /// El backend redirige a `${FRONTEND_URL}?token=<jwt>`, así que basta con
    /// arrancarlo con `FRONTEND_URL=finanz://auth`.
    static let oauthCallbackScheme = "finanz"

    private static let baseURLKey = "finanz.api.baseURL"

    /// URL base efectiva de la API (sin barra final).
    static var baseURL: URL {
        let raw = storedBaseURLString ?? defaultBaseURL
        return URL(string: raw) ?? URL(string: defaultBaseURL)!
    }

    /// Valor guardado por el usuario (nil si usa el valor por defecto).
    static var storedBaseURLString: String? {
        get {
            guard let value = UserDefaults.standard.string(forKey: baseURLKey),
                  !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return value
        }
        set {
            let cleaned = newValue.map { normalize($0) }
            if let cleaned, !cleaned.isEmpty, cleaned != defaultBaseURL {
                UserDefaults.standard.set(cleaned, forKey: baseURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: baseURLKey)
            }
        }
    }

    /// Tolera lo que se escribe a mano en Ajustes:
    ///   `finanz.kerbero.uk`         → `https://finanz.kerbero.uk/api`
    ///   `https://finanz.kerbero.uk` → `https://finanz.kerbero.uk/api`
    ///   `https://.../api/`          → `https://.../api`
    ///   `localhost:8090`            → `http://localhost:8090/api`
    ///
    /// Si la URL ya trae una ruta propia (un proxy inverso, por ejemplo), se
    /// respeta tal cual y no se le añade `/api`.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        guard !value.isEmpty else { return defaultBaseURL }

        let lowercased = value.lowercased()
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            // Se asume https salvo que sea una dirección local, que en
            // desarrollo va sin certificado.
            value = (isLocalAddress(value) ? "http://" : "https://") + value
        }

        // Solo añadimos /api cuando se dio únicamente host:puerto.
        if let range = value.range(of: "://"),
           !value[range.upperBound...].contains("/") {
            value += "/api"
        }
        return value
    }

    /// Direcciones locales o del simulador: son las únicas que en desarrollo se
    /// sirven sin TLS, así que a esas se les pone `http` y al resto `https`.
    private static func isLocalAddress(_ hostAndPort: String) -> Bool {
        let host = hostAndPort.split(separator: ":").first.map(String.init)?.lowercased() ?? ""
        return host == "localhost"
            || host.hasPrefix("192.168.")
            || host.hasPrefix("10.")
            || host.hasPrefix("127.")
    }

    /// Moneda y locale usados en toda la app (igual que la web: es-ES / EUR).
    static let locale = Locale(identifier: "es_ES")
    static let currencyCode = "EUR"
}
