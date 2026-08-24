import Foundation
import Observation

/// Estado de la conexión con el banco y de la bandeja de movimientos.
///
/// El detalle del flujo de vinculación: la autenticación NO ocurre dentro de la
/// app. Se abre `ASWebAuthenticationSession` con la URL que da el backend, el
/// usuario entra en la web del Santander —viendo el candado y el dominio de su
/// banco, como debe ser— y al terminar el backend redirige a `finanz://bank`,
/// que la sesión captura. La app nunca ve, ni pide, ni guarda credenciales
/// bancarias.
@MainActor
@Observable
final class BankViewModel {

    private(set) var status: BankStatus = .unavailable
    private(set) var institutions: [BankInstitution] = []
    private(set) var pending: [CardMovement] = []

    private(set) var isLoading = false
    private(set) var isLinking = false
    private(set) var syncingConnectionId: Int64?
    private(set) var busyMovementIds: Set<Int64> = []

    var errorMessage: String?
    var infoMessage: String?

    var hasConnections: Bool { !status.connections.isEmpty }
    var pendingTotal: Decimal { pending.reduce(0) { $0 + $1.amount } }

    /// Movimientos que tiene sentido apuntar de golpe: los cajeros no, porque
    /// el gasto de verdad viene después al pagar en efectivo.
    var bulkConfirmable: [CardMovement] { pending.filter { !$0.isCashWithdrawal } }

    // MARK: - Carga

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let status = BankService.status()
            async let pending = BankService.pendingMovements()
            self.status = try await status
            self.pending = try await pending
        } catch {
            errorMessage = message(from: error)
        }
    }

    func refreshQuietly() async {
        do {
            async let status = BankService.status()
            async let pending = BankService.pendingMovements()
            self.status = try await status
            self.pending = try await pending
        } catch {
            // Una recarga de fondo que falla no debe tapar la pantalla con un
            // error: lo que ya se está viendo sigue siendo válido.
        }
    }

    func loadInstitutions() async {
        guard institutions.isEmpty else { return }
        do {
            institutions = try await BankService.institutions()
        } catch {
            errorMessage = message(from: error)
        }
    }

    // MARK: - Vinculación

    func link(institution: BankInstitution) async {
        await runLink { try await BankService.startLink(institutionId: institution.id) }
    }

    func renew(connection: BankConnection) async {
        await runLink { try await BankService.renew(connectionId: connection.id) }
    }

    private func runLink(_ start: () async throws -> BankLinkStart) async {
        isLinking = true
        errorMessage = nil
        infoMessage = nil
        defer { isLinking = false }

        do {
            let link = try await start()
            guard let url = URL(string: link.authUrl) else {
                errorMessage = "El banco devolvió un enlace que no se entiende."
                return
            }

            _ = try await WebAuthenticator.shared.authenticate(
                url: url, callbackScheme: AppConfig.oauthCallbackScheme)

            // El backend ya cerró la vinculación al recibir la redirección y
            // lanzó la primera descarga en segundo plano. Aquí solo hay que
            // recoger el resultado.
            await load()
            infoMessage = status.connections.contains(where: { $0.isLinked })
                ? "Banco conectado. Los primeros movimientos tardan un momento en llegar."
                : "La autorización no llegó a completarse."

        } catch is WebAuthenticator.Cancelled {
            // Cerrar el navegador es una decisión, no un fallo.
            await refreshQuietly()
        } catch {
            errorMessage = message(from: error)
        }
    }

    func sync(connection: BankConnection) async {
        syncingConnectionId = connection.id
        errorMessage = nil
        infoMessage = nil
        defer { syncingConnectionId = nil }
        do {
            let result = try await BankService.sync(connectionId: connection.id)
            infoMessage = result.summary
            await refreshQuietly()
        } catch {
            errorMessage = message(from: error)
        }
    }

    func setAutoConfirm(connection: BankConnection, enabled: Bool) async {
        do {
            _ = try await BankService.setAutoConfirm(connectionId: connection.id, enabled: enabled)
            await refreshQuietly()
        } catch {
            errorMessage = message(from: error)
        }
    }

    func setAccountSync(connection: BankConnection, account: BankAccount, enabled: Bool) async {
        do {
            try await BankService.setAccountSync(connectionId: connection.id,
                                                 accountId: account.id, enabled: enabled)
            await refreshQuietly()
        } catch {
            errorMessage = message(from: error)
        }
    }

    func unlink(connection: BankConnection) async {
        errorMessage = nil
        do {
            try await BankService.unlink(connectionId: connection.id)
            infoMessage = "Banco desconectado. Los gastos que ya apuntaste siguen ahí."
            await load()
        } catch {
            errorMessage = message(from: error)
        }
    }

    // MARK: - Movimientos

    func confirm(_ movement: CardMovement, category: String? = nil) async {
        busyMovementIds.insert(movement.id)
        errorMessage = nil
        defer { busyMovementIds.remove(movement.id) }
        do {
            try await BankService.confirm(id: movement.id, category: category)
            remove(movement.id)
        } catch {
            errorMessage = message(from: error)
        }
    }

    func ignore(_ movement: CardMovement) async {
        busyMovementIds.insert(movement.id)
        errorMessage = nil
        defer { busyMovementIds.remove(movement.id) }
        do {
            try await BankService.ignore(id: movement.id)
            remove(movement.id)
        } catch {
            errorMessage = message(from: error)
        }
    }

    func confirmAll() async {
        let ids = bulkConfirmable.map(\.id)
        guard !ids.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let created = try await BankService.confirmAll(ids: ids)
            infoMessage = created.count == 1
                ? "1 gasto apuntado."
                : "\(created.count) gastos apuntados."
            await refreshQuietly()
        } catch {
            errorMessage = message(from: error)
        }
    }

    /// Quita el movimiento de la lista sin esperar a recargar, para que el
    /// botón responda al instante. El contador se ajusta a la vez.
    private func remove(_ id: Int64) {
        pending.removeAll { $0.id == id }
        status = BankStatus(available: status.available,
                            connections: status.connections,
                            pendingMovements: max(0, status.pendingMovements - 1))
    }

    private func message(from error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
