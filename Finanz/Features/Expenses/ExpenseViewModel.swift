import Foundation
import Observation

@MainActor
@Observable
final class ExpenseViewModel {

    var month: Int = Date().monthComponent
    var year: Int = Date().yearComponent
    var filterCategory: String = "Todas"

    private(set) var expenses: [Expense] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Recurrentes que tocan este mes y todavía no están apuntados.
    private(set) var suggestions: [RecurringSuggestion] = []
    private(set) var isApplyingSuggestions = false

    var suggestionsTotal: Decimal { suggestions.reduce(0) { $0 + $1.amount } }

    // MARK: - Derivados

    var total: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var filtered: [Expense] {
        filterCategory == "Todas"
            ? expenses
            : expenses.filter { $0.category == filterCategory }
    }

    var filteredTotal: Decimal {
        filtered.reduce(0) { $0 + $1.amount }
    }

    /// Totales por categoría, de mayor a menor (solo las que tienen gasto).
    var categoryTotals: [(category: ExpenseCategory, total: Decimal)] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
        var result: [(category: ExpenseCategory, total: Decimal)] = []
        for (name, items) in grouped {
            let sum = items.reduce(Decimal(0)) { partial, expense in partial + expense.amount }
            if sum > 0 {
                result.append((category: ExpenseCategory.find(name), total: sum))
            }
        }
        return result.sorted { $0.total > $1.total }
    }

    // MARK: - Acciones

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            expenses = try await ExpenseService.all(month: month, year: year)
        } catch is CancellationError {
            // Cambio de mes rápido: se ignora.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    /// Un fallo aquí no se enseña: las sugerencias son un extra y taparían el
    /// error de verdad si la lista de gastos también hubiese fallado.
    func loadSuggestions() async {
        suggestions = (try? await ExpenseService.suggestions(month: month, year: year)) ?? []
    }

    /// Incorpora al mes las series indicadas (por defecto, todas las sugeridas).
    func applySuggestions(seriesIds: [Int64]? = nil) async {
        let ids = seriesIds ?? suggestions.map(\.seriesId)
        guard !ids.isEmpty else { return }

        isApplyingSuggestions = true
        errorMessage = nil
        do {
            let created = try await ExpenseService.applySuggestions(seriesIds: ids,
                                                                    month: month, year: year)
            expenses.insert(contentsOf: created, at: 0)
            suggestions.removeAll { ids.contains($0.seriesId) }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isApplyingSuggestions = false
    }

    /// "No me lo propongas más": no borra nada de lo ya apuntado.
    func dismissSeries(_ seriesId: Int64) async {
        let snapshot = suggestions
        suggestions.removeAll { $0.seriesId == seriesId }
        do {
            try await ExpenseService.stopSeries(id: seriesId)
        } catch {
            suggestions = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func upsert(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        } else {
            expenses.insert(expense, at: 0)
        }
    }

    func delete(_ expense: Expense) async {
        let snapshot = expenses
        expenses.removeAll { $0.id == expense.id }
        do {
            try await ExpenseService.delete(id: expense.id)
        } catch {
            expenses = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
