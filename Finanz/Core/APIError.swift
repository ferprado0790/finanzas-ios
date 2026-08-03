import Foundation

/// Errores devueltos por la capa de red.
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case server(status: Int, message: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del servidor no es válida."
        case .unauthorized:
            return "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case let .server(status, message):
            return message.isEmpty ? "Error del servidor (\(status))." : message
        case let .decoding(detail):
            return "No se pudo leer la respuesta del servidor. \(detail)"
        case let .transport(detail):
            return "No se pudo conectar con el servidor. \(detail)"
        }
    }
}

/// Cuerpo de error estándar del backend: `{ "message": "..." }`.
struct APIErrorBody: Decodable {
    let message: String?
    let errors: [String: String]?
}
