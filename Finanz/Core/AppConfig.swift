import Foundation

/// Configuración global de la app.
///
/// La URL base se puede cambiar en tiempo de ejecución desde Ajustes, lo que
/// permite apuntar al backend local (simulador), a un backend en la red local
/// (dispositivo físico) o a un túnel/servidor remoto sin recompilar.
enum AppConfig {

    /// Backend por defecto: Spring Boot escucha en el puerto 8090 (ver `application.yml`).
    static let defaultBaseURL = "http://localhost:8090/api"

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
    ///   `192.168.1.136:8081`        → `http://192.168.1.136:8081/api`
    ///   `http://192.168.1.136:8081` → `http://192.168.1.136:8081/api`
    ///   `http://.../api/`           → `http://.../api`
    ///
    /// Si la URL ya trae una ruta propia (un proxy inverso, por ejemplo), se
    /// respeta tal cual y no se le añade `/api`.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        guard !value.isEmpty else { return defaultBaseURL }

        let lowercased = value.lowercased()
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            value = "http://" + value
        }

        // Solo añadimos /api cuando se dio únicamente host:puerto.
        if let range = value.range(of: "://"),
           !value[range.upperBound...].contains("/") {
            value += "/api"
        }
        return value
    }

    /// Moneda y locale usados en toda la app (igual que la web: es-ES / EUR).
    static let locale = Locale(identifier: "es_ES")
    static let currencyCode = "EUR"
}
