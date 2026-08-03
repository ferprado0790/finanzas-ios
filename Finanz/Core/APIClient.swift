import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describe una llamada a la API de `finanzas-backend`.
struct Endpoint {
    var path: String                       // Ej: "/expenses" (relativo a la baseURL, que ya incluye /api)
    var method: HTTPMethod = .get
    var query: [String: String] = [:]
    var body: Data?
    var requiresAuth: Bool = true

    static func json<T: Encodable>(_ path: String,
                                   method: HTTPMethod,
                                   body: T,
                                   requiresAuth: Bool = true) throws -> Endpoint {
        Endpoint(path: path,
                 method: method,
                 body: try JSONCoding.encoder.encode(body),
                 requiresAuth: requiresAuth)
    }
}

/// Codificadores compartidos: el backend usa `LocalDate` ("yyyy-MM-dd") y `BigDecimal`.
enum JSONCoding {

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            // Acepta "2025-06-01" y también ISO-8601 completo por si el backend cambia.
            if let date = dateFormatter.date(from: raw) { return date }
            if let date = ISO8601DateFormatter().date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Fecha no reconocida: \(raw)")
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter.string(from: date))
        }
        return e
    }()
}

/// Cliente HTTP de la app. Añade el JWT, decodifica JSON y traduce errores.
final class APIClient: @unchecked Sendable {

    static let shared = APIClient()

    /// Se emite cuando el backend responde 401: la sesión debe cerrarse.
    static let unauthorizedNotification = Notification.Name("finanz.unauthorized")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - API pública

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await perform(endpoint)
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Para endpoints que devuelven 204 o cuyo cuerpo no interesa.
    func sendIgnoringResponse(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    // MARK: - Implementación

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        let request = try buildRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Respuesta no válida.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONCoding.decoder.decode(APIErrorBody.self, from: data)
            var message = body?.message ?? ""
            if let fieldErrors = body?.errors, !fieldErrors.isEmpty {
                let detail = fieldErrors.map { "\($0.key): \($0.value)" }.sorted().joined(separator: ", ")
                message = message.isEmpty ? detail : "\(message) (\(detail))"
            }

            if http.statusCode == 401 {
                // Un 401 solo significa "sesión caducada" si había sesión. Al
                // iniciar sesión significa credenciales incorrectas, y el
                // backend lo explica en el cuerpo: hay que respetar ese texto.
                let hadSession = TokenStore.token != nil
                if hadSession {
                    NotificationCenter.default.post(name: APIClient.unauthorizedNotification, object: nil)
                }
                if !message.isEmpty {
                    throw APIError.server(status: 401, message: message)
                }
                throw hadSession ? APIError.unauthorized
                                 : APIError.server(status: 401, message: "Credenciales incorrectas.")
            }

            throw APIError.server(status: http.statusCode, message: message)
        }

        return data
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        let base = AppConfig.baseURL
        guard var components = URLComponents(url: base.appendingPathComponent(endpoint.path.trimmedLeadingSlash),
                                             resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if endpoint.requiresAuth, let token = TokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

/// Marcador para endpoints que responden 204 / cuerpo vacío.
struct EmptyResponse: Decodable {}

private extension String {
    var trimmedLeadingSlash: String {
        hasPrefix("/") ? String(dropFirst()) : self
    }
}
