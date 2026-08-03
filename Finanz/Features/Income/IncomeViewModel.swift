import Foundation
import Observation

@MainActor
@Observable
final class IncomeViewModel {

    var month: Int = Date().monthComponent
    var year: Int = Date().yearComponent

    private(set) var jobs: [Job] = []
    private(set) var incomes: [Income] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var total: Decimal {
        incomes.reduce(0) { $0 + $1.amount }
    }

    /// Total cobrado en el mes por cada trabajo y su avance sobre lo esperado.
    func progress(for job: Job) -> (total: Decimal, fraction: Double) {
        let total = incomes.filter { $0.jobId == job.id }.reduce(Decimal(0)) { $0 + $1.amount }
        guard let expected = job.expectedMonthly, expected > 0 else { return (total, 0) }
        return (total, min((total / expected).doubleValue, 1))
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let jobsTask = JobService.all()
            async let incomesTask = IncomeService.all(month: month, year: year)
            let (loadedJobs, loadedIncomes) = try await (jobsTask, incomesTask)
            jobs = loadedJobs
            incomes = loadedIncomes
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    func deleteJob(_ job: Job) async {
        let snapshot = jobs
        jobs.removeAll { $0.id == job.id }
        do {
            try await JobService.delete(id: job.id)
        } catch {
            jobs = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deleteIncome(_ income: Income) async {
        let snapshot = incomes
        incomes.removeAll { $0.id == income.id }
        do {
            try await IncomeService.delete(id: income.id)
        } catch {
            incomes = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
