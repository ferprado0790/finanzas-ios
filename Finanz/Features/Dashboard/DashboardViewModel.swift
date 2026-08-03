import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    private(set) var summary: BudgetSummary = .empty
    private(set) var recentExpenses: [Expense] = []
    private(set) var isLoading = false
    var errorMessage: String?

    let month = Date().monthComponent
    let year = Date().yearComponent

    var monthTitle: String {
        "\(Formatters.monthNames[month - 1]) \(String(year))"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let summaryTask = BudgetService.summary(month: month, year: year)
            async let expensesTask = ExpenseService.all(month: month, year: year)
            let (loadedSummary, loadedExpenses) = try await (summaryTask, expensesTask)
            summary = loadedSummary
            recentExpenses = Array(loadedExpenses.prefix(5))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
