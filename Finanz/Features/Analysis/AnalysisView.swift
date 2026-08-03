import SwiftUI
import Charts
import Observation

@MainActor
@Observable
final class AnalysisViewModel {

    private(set) var trend: [TrendPoint] = []
    private(set) var summary: BudgetSummary = .empty
    private(set) var isLoading = false
    var errorMessage: String?

    var categories: [CategoryBreakdown] {
        (summary.categoryBreakdown ?? []).sorted { $0.amount > $1.amount }
    }

    /// Mismas recomendaciones que `AnalysisPage.jsx`.
    var tips: [(icon: String, color: Color, text: String)] {
        var result: [(String, Color, String)] = []
        if summary.savingsRate < 20 {
            result.append(("exclamationmark.triangle.fill", Theme.warning,
                           "Tu tasa de ahorro está por debajo del 20 % recomendado."))
        }
        if summary.savingsRate >= 30 {
            result.append(("checkmark.seal.fill", Theme.success,
                           "¡Excelente! Estás ahorrando más del 30 % de tus ingresos."))
        }
        if let top = categories.first {
            result.append(("chart.bar.fill", Theme.primary,
                           "Tu mayor gasto es \(top.category) (\(top.pct) % del total)."))
        }
        if summary.balance < 0 {
            result.append(("exclamationmark.octagon.fill", Theme.danger,
                           "Tus gastos superan tus ingresos este mes."))
        }
        return result.map { (icon: $0.0, color: $0.1, text: $0.2) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        let month = Date().monthComponent
        let year = Date().yearComponent
        do {
            async let trendTask = BudgetService.trend(months: 6)
            async let summaryTask = BudgetService.summary(month: month, year: year)
            let (loadedTrend, loadedSummary) = try await (trendTask, summaryTask)
            trend = loadedTrend
            summary = loadedSummary
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

/// Puerto de `AnalysisPage.jsx`, con Swift Charts para la tendencia.
struct AnalysisView: View {

    @State private var vm = AnalysisViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = vm.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await vm.load() }
                    }
                }

                kpiGrid
                trendCard
                distributionCard
                tipsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .finanzBackground()
        .navigationTitle("Tu situación financiera")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }

    // MARK: - Secciones

    private var kpiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            kpi("Ingresos totales", vm.summary.totalIncome.currencyString, Theme.success)
            kpi("Gastos totales", "-\(vm.summary.totalExpenses.currencyString)", Theme.danger)
            kpi("Balance neto", vm.summary.balance.currencyString, Theme.balanceColor(vm.summary.balance))
            kpi("Tasa de ahorro", "\(vm.summary.savingsRate) %", Theme.savingsColor(vm.summary.savingsRate))
        }
    }

    private func kpi(_ label: String, _ value: String, _ color: Color) -> some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textMuted)
                Text(value)
                    .font(.display(19))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tendencia últimos 6 meses")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textBody)

                if vm.trend.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "Sin datos suficientes todavía")
                } else {
                    Chart {
                        ForEach(vm.trend) { point in
                            BarMark(
                                x: .value("Mes", point.month),
                                y: .value("Importe", point.income.doubleValue)
                            )
                            .foregroundStyle(by: .value("Serie", "Ingresos"))
                            .position(by: .value("Serie", "Ingresos"))

                            BarMark(
                                x: .value("Mes", point.month),
                                y: .value("Importe", point.expenses.doubleValue)
                            )
                            .foregroundStyle(by: .value("Serie", "Gastos"))
                            .position(by: .value("Serie", "Gastos"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Ingresos": Theme.primary,
                        "Gastos": Theme.danger
                    ])
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Theme.border)
                            AxisValueLabel()
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .frame(height: 190)
                }
            }
        }
    }

    @ViewBuilder
    private var distributionCard: some View {
        if !vm.categories.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Distribución de gastos")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textBody)

                    ForEach(vm.categories) { item in
                        VStack(spacing: 5) {
                            HStack {
                                Text(item.category)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textBody)
                                Spacer()
                                Text("\(item.pct) % · \(item.amount.currencyString)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            ProgressBar(value: Double(item.pct) / 100,
                                        color: ExpenseCategory.color(for: item.category),
                                        height: 8)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tipsSection: some View {
        if !vm.tips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Recomendaciones")
                ForEach(Array(vm.tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tip.icon)
                            .foregroundStyle(tip.color)
                        Text(tip.text)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tip.color.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
    }
}
