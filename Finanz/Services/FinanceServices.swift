import Foundation

/// Equivalente nativo de `apiService.js`, dividido por dominio.

// MARK: - Trabajos

enum JobService {
    static func all() async throws -> [Job] {
        try await APIClient.shared.send(Endpoint(path: "/jobs"))
    }

    static func create(_ request: JobRequest) async throws -> Job {
        try await APIClient.shared.send(Endpoint.json("/jobs", method: .post, body: request))
    }

    static func update(id: Int64, _ request: JobRequest) async throws -> Job {
        try await APIClient.shared.send(Endpoint.json("/jobs/\(id)", method: .put, body: request))
    }

    /// El backend desactiva el trabajo (soft delete).
    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(Endpoint(path: "/jobs/\(id)", method: .delete))
    }
}

// MARK: - Ingresos

enum IncomeService {
    static func all(month: Int, year: Int) async throws -> [Income] {
        try await APIClient.shared.send(
            Endpoint(path: "/incomes", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func create(_ request: IncomeRequest) async throws -> Income {
        try await APIClient.shared.send(Endpoint.json("/incomes", method: .post, body: request))
    }

    static func update(id: Int64, _ request: IncomeRequest) async throws -> Income {
        try await APIClient.shared.send(Endpoint.json("/incomes/\(id)", method: .put, body: request))
    }

    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(Endpoint(path: "/incomes/\(id)", method: .delete))
    }
}

// MARK: - Gastos

enum ExpenseService {
    static func all(month: Int, year: Int) async throws -> [Expense] {
        try await APIClient.shared.send(
            Endpoint(path: "/expenses", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func byCategory(month: Int, year: Int) async throws -> [CategoryBreakdown] {
        try await APIClient.shared.send(
            Endpoint(path: "/expenses/by-category", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func create(_ request: ExpenseRequest) async throws -> Expense {
        try await APIClient.shared.send(Endpoint.json("/expenses", method: .post, body: request))
    }

    static func update(id: Int64, _ request: ExpenseRequest) async throws -> Expense {
        try await APIClient.shared.send(Endpoint.json("/expenses/\(id)", method: .put, body: request))
    }

    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(Endpoint(path: "/expenses/\(id)", method: .delete))
    }

    /// Sitios donde ya has gastado en esa categoría, los más usados primero.
    static func frequent(category: String, limit: Int = 8) async throws -> [FrequentExpense] {
        try await APIClient.shared.send(
            Endpoint(path: "/expenses/frequent",
                     query: ["category": category, "limit": "\(limit)"])
        )
    }

    // MARK: Recurrentes

    static func suggestions(month: Int, year: Int) async throws -> [RecurringSuggestion] {
        try await APIClient.shared.send(
            Endpoint(path: "/expenses/suggestions", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func applySuggestions(seriesIds: [Int64], month: Int, year: Int) async throws -> [Expense] {
        try await APIClient.shared.send(
            Endpoint.json("/expenses/suggestions/apply", method: .post,
                          body: ApplySuggestionsRequest(seriesIds: seriesIds, month: month, year: year))
        )
    }

    /// Copia el gasto a los próximos `months` meses, saltando los que ya lo tienen.
    static func replicate(id: Int64, months: Int) async throws -> [Expense] {
        try await APIClient.shared.send(
            Endpoint.json("/expenses/\(id)/replicate", method: .post,
                          body: ReplicateRequest(months: months))
        )
    }

    static func stopSeries(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/expenses/series/\(id)/stop", method: .post)
        )
    }

    static func resumeSeries(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/expenses/series/\(id)/resume", method: .post)
        )
    }
}

// MARK: - Presupuesto / análisis / informes

enum BudgetService {
    static func summary(month: Int, year: Int) async throws -> BudgetSummary {
        try await APIClient.shared.send(
            Endpoint(path: "/budget/summary", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func trend(months: Int = 6) async throws -> [TrendPoint] {
        try await APIClient.shared.send(
            Endpoint(path: "/budget/trend", query: ["months": "\(months)"])
        )
    }

    static func limits() async throws -> [BudgetLimit] {
        try await APIClient.shared.send(Endpoint(path: "/budget/limits"))
    }

    static func setLimit(category: String, limit: Decimal) async throws -> BudgetLimit {
        try await APIClient.shared.send(
            Endpoint.json("/budget/limits", method: .post,
                          body: BudgetLimitRequest(category: category, limit: limit))
        )
    }

    static func checkExpense(_ request: CheckExpenseRequest) async throws -> CheckExpenseResult {
        try await APIClient.shared.send(
            Endpoint.json("/budget/check-expense", method: .post, body: request)
        )
    }

    /// Aviso mientras se escribe el importe: ¿estaba previsto y hay presupuesto?
    static func spendAlert(_ request: SpendAlertRequest) async throws -> SpendAlert {
        try await APIClient.shared.send(
            Endpoint.json("/budget/spend-alert", method: .post, body: request)
        )
    }

    static func report(fromMonth: Int, fromYear: Int,
                       toMonth: Int, toYear: Int) async throws -> PeriodReport {
        try await APIClient.shared.send(
            Endpoint(path: "/budget/report", query: [
                "fromMonth": "\(fromMonth)", "fromYear": "\(fromYear)",
                "toMonth": "\(toMonth)", "toYear": "\(toYear)"
            ])
        )
    }
}

// MARK: - Lista de la compra

enum ShoppingListService {
    static func all() async throws -> [ShoppingItem] {
        try await APIClient.shared.send(Endpoint(path: "/shopping-list"))
    }

    static func create(_ request: ShoppingItemRequest) async throws -> ShoppingItem {
        try await APIClient.shared.send(Endpoint.json("/shopping-list", method: .post, body: request))
    }

    static func update(id: Int64, _ request: ShoppingItemRequest) async throws -> ShoppingItem {
        try await APIClient.shared.send(Endpoint.json("/shopping-list/\(id)", method: .put, body: request))
    }

    static func togglePurchased(id: Int64) async throws -> ShoppingItem {
        try await APIClient.shared.send(Endpoint(path: "/shopping-list/\(id)/toggle", method: .patch))
    }

    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(Endpoint(path: "/shopping-list/\(id)", method: .delete))
    }
}

// MARK: - Facturas de la compra

/// El OCR lo hace el propio iPhone (ver `ReceiptScanner`): aquí solo viaja el
/// texto reconocido de cada foto.
enum ReceiptService {
    static func all(month: Int, year: Int) async throws -> [Receipt] {
        try await APIClient.shared.send(
            Endpoint(path: "/receipts", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func drafts() async throws -> [Receipt] {
        try await APIClient.shared.send(Endpoint(path: "/receipts/drafts"))
    }

    static func summary(month: Int, year: Int) async throws -> ReceiptSummary {
        try await APIClient.shared.send(
            Endpoint(path: "/receipts/summary", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    static func get(id: Int64) async throws -> Receipt {
        try await APIClient.shared.send(Endpoint(path: "/receipts/\(id)"))
    }

    static func create(_ request: ReceiptRequest) async throws -> Receipt {
        try await APIClient.shared.send(Endpoint.json("/receipts", method: .post, body: request))
    }

    static func update(id: Int64, _ request: ReceiptRequest) async throws -> Receipt {
        try await APIClient.shared.send(Endpoint.json("/receipts/\(id)", method: .put, body: request))
    }

    static func addPage(id: Int64, rawText: String) async throws -> Receipt {
        try await APIClient.shared.send(
            Endpoint.json("/receipts/\(id)/pages", method: .post,
                          body: ReceiptPageRequest(rawText: rawText))
        )
    }

    static func deletePage(id: Int64, pageIndex: Int) async throws -> Receipt {
        try await APIClient.shared.send(
            Endpoint(path: "/receipts/\(id)/pages/\(pageIndex)", method: .delete)
        )
    }

    static func addItem(id: Int64, _ request: ReceiptItemRequest) async throws -> Receipt {
        try await APIClient.shared.send(
            Endpoint.json("/receipts/\(id)/items", method: .post, body: request)
        )
    }

    static func updateItem(id: Int64, itemId: Int64, _ request: ReceiptItemRequest) async throws -> Receipt {
        try await APIClient.shared.send(
            Endpoint.json("/receipts/\(id)/items/\(itemId)", method: .put, body: request)
        )
    }

    static func deleteItem(id: Int64, itemId: Int64) async throws -> Receipt {
        try await APIClient.shared.send(
            Endpoint(path: "/receipts/\(id)/items/\(itemId)", method: .delete)
        )
    }

    /// Cierra el ticket y devuelve además el repaso de la lista de la compra.
    static func confirm(id: Int64) async throws -> ReceiptConfirmation {
        try await APIClient.shared.send(Endpoint(path: "/receipts/\(id)/confirm", method: .post))
    }

    static func reopen(id: Int64) async throws -> Receipt {
        try await APIClient.shared.send(Endpoint(path: "/receipts/\(id)/reopen", method: .post))
    }

    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(Endpoint(path: "/receipts/\(id)", method: .delete))
    }
}

// MARK: - Divisor de cuenta

/// Los comensales son nombres sueltos: no hace falta que tengan cuenta.
enum BillSplitService {
    static func all(month: Int, year: Int) async throws -> [BillSplit] {
        try await APIClient.shared.send(
            Endpoint(path: "/bill-splits", query: ["month": "\(month)", "year": "\(year)"])
        )
    }

    /// Cuentas en las que todavía te debe alguien.
    static func open() async throws -> [BillSplit] {
        try await APIClient.shared.send(Endpoint(path: "/bill-splits/open"))
    }

    static func get(id: Int64) async throws -> BillSplit {
        try await APIClient.shared.send(Endpoint(path: "/bill-splits/\(id)"))
    }

    static func create(_ request: BillSplitRequest) async throws -> BillSplit {
        try await APIClient.shared.send(Endpoint.json("/bill-splits", method: .post, body: request))
    }

    static func update(id: Int64, _ request: BillSplitRequest) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint.json("/bill-splits/\(id)", method: .put, body: request)
        )
    }

    static func readPhoto(id: Int64, rawText: String) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint.json("/bill-splits/\(id)/photo", method: .post,
                          body: BillOcrRequest(rawText: rawText))
        )
    }

    static func addParticipant(id: Int64, name: String) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint.json("/bill-splits/\(id)/participants", method: .post,
                          body: ParticipantRequest(name: name))
        )
    }

    static func removeParticipant(id: Int64, participantId: Int64) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint(path: "/bill-splits/\(id)/participants/\(participantId)", method: .delete)
        )
    }

    static func toggleSettled(id: Int64, participantId: Int64) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint(path: "/bill-splits/\(id)/participants/\(participantId)/settle", method: .patch)
        )
    }

    static func addItem(id: Int64, _ request: BillItemRequest) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint.json("/bill-splits/\(id)/items", method: .post, body: request)
        )
    }

    static func updateItem(id: Int64, itemId: Int64, _ request: BillItemRequest) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint.json("/bill-splits/\(id)/items/\(itemId)", method: .put, body: request)
        )
    }

    static func deleteItem(id: Int64, itemId: Int64) async throws -> BillSplit {
        try await APIClient.shared.send(
            Endpoint(path: "/bill-splits/\(id)/items/\(itemId)", method: .delete)
        )
    }

    /// Apunta tu parte como gasto. Solo la tuya.
    static func confirm(id: Int64) async throws -> BillSplit {
        try await APIClient.shared.send(Endpoint(path: "/bill-splits/\(id)/confirm", method: .post))
    }

    static func delete(id: Int64) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint(path: "/bill-splits/\(id)", method: .delete)
        )
    }
}

// MARK: - Avisos push

enum DeviceService {
    /// Se llama en cada arranque con sesión: el sistema rota el token.
    static func register(token: String) async throws {
        try await APIClient.shared.sendIgnoringResponse(
            Endpoint.json("/devices", method: .post, body: DeviceTokenRequest(token: token))
        )
    }
}
