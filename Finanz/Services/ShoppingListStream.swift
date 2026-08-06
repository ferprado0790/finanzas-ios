import Foundation

/// Un cambio en la lista de la compra llegado por el canal en vivo.
struct ShoppingListEvent: Decodable {
    let type: String            // CREATED | UPDATED | DELETED
    let itemId: Int64
    /// El artículo ya actualizado. Nulo en los borrados.
    let item: ShoppingItem?
    /// De dónde viene: USER o RECEIPT (al escanear un ticket).
    let origin: String?
}

/**
 Cambios de la lista de la compra según ocurren, vengan de este iPhone, de otro
 dispositivo o de un ticket recién escaneado.

 Va por Server-Sent Events sobre `URLSession.bytes`, que ya sabe entregar la
 respuesta línea a línea según llega: no hace falta ninguna librería.
 */
enum ShoppingListStream {

    private static let eventName = "shopping-list"

    /// Espera antes de reintentar tras una caída, para no machacar al servidor.
    private static let retryDelay: Duration = .seconds(3)

    /**
     Flujo de cambios que se reconecta solo. Termina cuando se cancela la tarea
     que lo consume (al cerrar la pantalla).
     */
    static func events() -> AsyncStream<ShoppingListEvent> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        try await consume { continuation.yield($0) }
                    } catch {
                        // Caída de red o servidor reiniciado: se reintenta.
                    }
                    if Task.isCancelled { break }
                    try? await Task.sleep(for: retryDelay)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Abre la conexión y va entregando eventos hasta que se corte.
    private static func consume(onEvent: (ShoppingListEvent) -> Void) async throws {
        guard let token = TokenStore.token else { throw APIError.unauthorized }

        var request = URLRequest(
            url: AppConfig.baseURL.appendingPathComponent("shopping-list/stream")
        )
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Entre evento y evento pueden pasar minutos sin que llegue nada.
        request.timeoutInterval = .infinity

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.transport("El canal en vivo rechazó la conexión.")
        }

        var eventName = "message"
        var dataLines: [String] = []

        for try await line in bytes.lines {
            if line.isEmpty {
                // Línea en blanco: se cierra el evento acumulado.
                defer {
                    eventName = "message"
                    dataLines.removeAll()
                }
                guard eventName == Self.eventName, !dataLines.isEmpty else { continue }
                if let event = decode(dataLines.joined(separator: "\n")) {
                    onEvent(event)
                }
            } else if line.hasPrefix(":") {
                continue                                   // comentario: es el latido
            } else if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private static func decode(_ payload: String) -> ShoppingListEvent? {
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONCoding.decoder.decode(ShoppingListEvent.self, from: data)
    }
}
