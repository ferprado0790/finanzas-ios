import Foundation

// MARK: - Trabajos

/// `JobDto`
struct Job: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let type: String
    let expectedMonthly: Decimal?
    let active: Bool
}

/// `JobRequest`
struct JobRequest: Encodable {
    let name: String
    let type: String
    let expectedMonthly: Decimal?
}

// MARK: - Ingresos

/// `IncomeDto`
struct Income: Codable, Identifiable, Hashable {
    let id: Int64
    let description: String
    let amount: Decimal
    let jobId: Int64?
    let jobName: String?
    let date: Date
    let recurring: Bool
}

/// `IncomeRequest`
struct IncomeRequest: Encodable {
    let description: String
    let amount: Decimal
    let jobId: Int64?
    let date: Date
    let recurring: Bool
}

// MARK: - Gastos

/// `ExpenseDto`
struct Expense: Codable, Identifiable, Hashable {
    let id: Int64
    let description: String
    let amount: Decimal
    let category: String
    let date: Date
    let frequency: String?
    let notes: String?
    /// Agrupa las copias de un gasto recurrente. Nulo si es puntual.
    let seriesId: Int64?
    /// Mientras esté activa, la serie se sigue proponiendo cada mes.
    let recurringActive: Bool
}

// MARK: - Alta rápida

/// `FrequentExpenseDto` — sitio donde ya has gastado, para no teclearlo otra vez.
struct FrequentExpense: Decodable, Identifiable, Hashable {
    var id: String { description }
    let description: String
    let category: String
    /// Importe de la última vez: el mejor punto de partida.
    let lastAmount: Decimal
    let averageAmount: Decimal
    let timesUsed: Int
    let lastDate: Date
}

// MARK: - Gastos recurrentes

/// `RecurringSuggestionDto` — un fijo que toca este mes y no está apuntado.
struct RecurringSuggestion: Decodable, Identifiable, Hashable {
    var id: Int64 { seriesId }
    let seriesId: Int64
    let sourceExpenseId: Int64
    let description: String
    let amount: Decimal
    let category: String
    let frequency: String
    let notes: String?
    let lastDate: Date
    let suggestedDate: Date
    /// Veces que se ha repetido ya: da idea de lo fiable que es la sugerencia.
    let occurrences: Int
}

/// `ApplySuggestionsRequest`
struct ApplySuggestionsRequest: Encodable {
    let seriesIds: [Int64]
    var month: Int?
    var year: Int?
}

/// `ReplicateRequest` — o los próximos `months`, o un mes concreto.
struct ReplicateRequest: Encodable {
    var months: Int?
    var targetMonth: Int?
    var targetYear: Int?
}

/// `ExpenseRequest`
struct ExpenseRequest: Encodable {
    let description: String
    let amount: Decimal
    let category: String
    let date: Date
    let frequency: String?
    let notes: String?
}

// MARK: - Presupuesto y análisis

/// `CategoryBreakdownDto`
struct CategoryBreakdown: Codable, Identifiable, Hashable {
    var id: String { category }
    let category: String
    let amount: Decimal
    let pct: Int
}

/// `BudgetSummaryDto`
struct BudgetSummary: Codable, Hashable {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let balance: Decimal
    let savingsRate: Int
    let jobCount: Int
    let categoryBreakdown: [CategoryBreakdown]?

    static let empty = BudgetSummary(totalIncome: 0, totalExpenses: 0, balance: 0,
                                     savingsRate: 0, jobCount: 0, categoryBreakdown: [])
}

/// `TrendDto` — `month` es una etiqueta ya formateada por el backend ("jun", "jun 2025").
struct TrendPoint: Codable, Identifiable, Hashable {
    var id: String { month }
    let month: String
    let income: Decimal
    let expenses: Decimal

    var balance: Decimal { income - expenses }
}

/// `BudgetLimitDto`
struct BudgetLimit: Codable, Identifiable, Hashable {
    let id: Int64?
    let category: String
    let limit: Decimal
    let spent: Decimal
    let pct: Int
}

/// `BudgetLimitRequest`
struct BudgetLimitRequest: Encodable {
    let category: String
    let limit: Decimal
}

/// `CheckExpenseRequest`
struct CheckExpenseRequest: Encodable {
    let amount: Decimal
    let category: String?
    let fromMonth: Int?
    let fromYear: Int?
    let toMonth: Int?
    let toYear: Int?
}

/// `CheckExpenseResponse`
struct CheckExpenseResult: Decodable, Hashable {
    let approved: Bool
    let canAfford: Bool
    let remainingAfter: Decimal
    let newSavingsRate: Int
    let categoryLimitExceeded: Bool
    let risk: String            // low | medium | high
    let message: String
    let suggestions: [String]?
}

/// `SpendAlertRequest` — gasto que se está a punto de apuntar.
struct SpendAlertRequest: Encodable {
    var description: String?
    let amount: Decimal
    var category: String?
    var date: Date?
}

/// `SpendAlertDto` — si el gasto estaba previsto y si hay presupuesto.
/// Nunca bloquea el alta; solo informa.
struct SpendAlert: Decodable, Hashable {
    let level: String                   // OK | CAUTION | WARNING
    let planned: Bool
    let plannedReason: String?          // RECURRING | SHOPPING_LIST | CATEGORY_BUDGET
    let plannedDetail: String?
    let matchedShoppingItemId: Int64?
    let title: String
    let message: String
    let suggestions: [String]?
    let canAfford: Bool
    let balanceBefore: Decimal
    let balanceAfter: Decimal
    let savingsRateAfter: Int
    let unplannedSpentThisMonth: Decimal
    let categoryLimit: Decimal?
    let categorySpentBefore: Decimal
    let categorySpentAfter: Decimal
    let categoryLimitExceeded: Bool
}

/// `PeriodReportDto`
struct PeriodReport: Decodable, Hashable {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let balance: Decimal
    let savingsRate: Int
    let avgMonthlyIncome: Decimal
    let avgMonthlyExpenses: Decimal
    let avgMonthlyBalance: Decimal
    let categoryBreakdown: [CategoryBreakdown]?
    let monthlyTrend: [TrendPoint]?
    let monthCount: Int
}

// MARK: - Lista de la compra

/// `ShoppingItemDto`
struct ShoppingItem: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    /// Precio estimado, el que escribe el usuario.
    let price: Decimal?
    /// Lo que costó de verdad la última vez, sacado del ticket escaneado.
    let lastPaidPrice: Decimal?
    let purchased: Bool
    /// Cada cuántos meses toca reponerlo. Nulo si es una compra suelta.
    let recurrenceMonths: Int?
    let lastPurchasedAt: Date?
    let nextDueDate: Date?
    /// Días que faltan para que vuelva; negativo si ya tocaba.
    let daysUntilDue: Int?

    /// Precio que merece la pena enseñar: manda lo que se pagó de verdad.
    var effectivePrice: Decimal? { lastPaidPrice ?? price }
}

/// `ShoppingItemRequest`
struct ShoppingItemRequest: Encodable {
    let name: String
    let price: Decimal?
    /// 1 = todos los meses, 3 = cada tres… Nulo para compra suelta.
    var recurrenceMonths: Int?
}
