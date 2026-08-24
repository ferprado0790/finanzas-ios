import Foundation

/// Llamadas a `/api/bank` y `/api/card-movements`.
enum BankService {

    // MARK: - Estado y bancos

    static func status() async throws -> BankStatus {
        try await APIClient.shared.send(Endpoint(path: "/bank/status"), as: BankStatus.self)
    }

    static func institutions() async throws -> [BankInstitution] {
        try await APIClient.shared.send(Endpoint(path: "/bank/institutions"), as: [BankInstitution].self)
    }

    // MARK: - Vinculación

    /// Arranca la vinculación. `client=mobile` hace que el banco devuelva a
    /// `finanz://bank`, que es lo que captura `ASWebAuthenticationSession`.
    static func startLink(institutionId: String) async throws -> BankLinkStart {
        try await APIClient.shared.send(
            Endpoint(path: "/bank/link",
                     method: .post,
                     query: ["client": "mobile"],
                     body: try JSONCoding.encoder.encode(["institutionId": institutionId])),
            as: BankLinkStart.self)
    }

    static func renew(connectionId: Int64) async throws -> BankLinkStart {
        try await APIClient.shared.send(
            Endpoint(path: "/bank/connections/\(connectionId)/renew",
                     method: .post,
                     query: ["client": "mobile"]),
            as: BankLinkStart.self)
    }

    static func sync(connectionId: Int64) async throws -> BankSyncResult {
        try await APIClient.shared.send(
            Endpoint(path: "/bank/connections/\(connectionId)/sync", method: .post),
            as: BankSyncResult.self)
    }

    static func setAutoConfirm(connectionId: Int64, enabled: Bool) async throws -> BankConnection {
        try await APIClient.shared.send(
            Endpoint.json("/bank/connections/\(connectionId)/auto-confirm",
                          method: .patch,
                          body: AutoConfirmRequest(autoConfirm: enabled)),
            as: BankConnection.self)
    }

    static func setAccountSync(connectionId: Int64, accountId: Int64, enabled: Bool) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/bank/connections/\(connectionId)/accounts/\(accountId)",
                     method: .patch,
                     query: ["enabled": enabled ? "true" : "false"]))
    }

    static func unlink(connectionId: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/bank/connections/\(connectionId)", method: .delete))
    }

    // MARK: - Movimientos

    static func pendingMovements() async throws -> [CardMovement] {
        try await APIClient.shared.send(Endpoint(path: "/card-movements/pending"),
                                        as: [CardMovement].self)
    }

    static func movements(month: Int, year: Int) async throws -> [CardMovement] {
        try await APIClient.shared.send(
            Endpoint(path: "/card-movements",
                     query: ["month": String(month), "year": String(year)]),
            as: [CardMovement].self)
    }

    /// Apunta el movimiento como gasto. Sin categoría se usa la propuesta.
    @discardableResult
    static func confirm(id: Int64, category: String? = nil,
                        description: String? = nil, notes: String? = nil) async throws -> Expense {
        try await APIClient.shared.send(
            Endpoint.json("/card-movements/\(id)/confirm",
                          method: .post,
                          body: ConfirmMovementRequest(category: category,
                                                       description: description,
                                                       notes: notes)),
            as: Expense.self)
    }

    static func ignore(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/card-movements/\(id)/ignore", method: .post))
    }

    @discardableResult
    static func confirmAll(ids: [Int64]) async throws -> [Expense] {
        try await APIClient.shared.send(
            Endpoint.json("/card-movements/confirm-all",
                          method: .post,
                          body: BulkConfirmRequest(ids: ids)),
            as: [Expense].self)
    }
}
