import SwiftUI
import Observation

/// Tipos de periodo del informe (mismos que `ReportPage.jsx`).
enum ReportPeriodKind: String, CaseIterable, Identifiable {
    case quarterly = "Trimestral"
    case biannual = "Semestral"
    case annual = "Anual"

    var id: String { rawValue }

    var options: [ReportPeriodOption] {
        switch self {
        case .quarterly:
            return [
                .init(label: "T1 (Ene–Mar)", from: 1, to: 3),
                .init(label: "T2 (Abr–Jun)", from: 4, to: 6),
                .init(label: "T3 (Jul–Sep)", from: 7, to: 9),
                .init(label: "T4 (Oct–Dic)", from: 10, to: 12)
            ]
        case .biannual:
            return [
                .init(label: "S1 (Ene–Jun)", from: 1, to: 6),
                .init(label: "S2 (Jul–Dic)", from: 7, to: 12)
            ]
        case .annual:
            return [.init(label: "Año completo (Ene–Dic)", from: 1, to: 12)]
        }
    }
}

struct ReportPeriodOption: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let from: Int
    let to: Int
}

@MainActor
@Observable
final class ReportViewModel {

    var kind: ReportPeriodKind = .quarterly {
        didSet { optionIndex = 0 }
    }
    var optionIndex = 0
    var year = Date().yearComponent

    private(set) var report: PeriodReport?
    private(set) var isLoading = false
    var errorMessage: String?

    var years: [Int] {
        let current = Date().yearComponent
        return (0..<5).map { current - $0 }
    }

    var option: ReportPeriodOption {
        let options = kind.options
        return options[min(optionIndex, options.count - 1)]
    }

    func generate() async {
        isLoading = true
        errorMessage = nil
        report = nil
        do {
            report = try await BudgetService.report(fromMonth: option.from,
                                                    fromYear: year,
                                                    toMonth: option.to,
                                                    toYear: year)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

/// Puerto de `ReportPage.jsx`.
struct ReportView: View {

    @State private var vm = ReportViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                configurationCard

                if let errorMessage = vm.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await vm.generate() }
                    }
                }

                if let report = vm.report {
                    summaryCard(report)
                    trendCard(report)
                    breakdownCard(report)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .finanzBackground()
        .navigationTitle("Informe financiero")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Configuración

    private var configurationCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Tipo de periodo")
                HStack(spacing: 8) {
                    ForEach(ReportPeriodKind.allCases) { kind in
                        Button {
                            vm.kind = kind
                        } label: {
                            Text(kind.rawValue)
                                .font(.system(size: 13, weight: vm.kind == kind ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .foregroundStyle(vm.kind == kind ? Theme.primaryLight : Theme.textMuted)
                                .background(vm.kind == kind ? Theme.primary.opacity(0.13) : Theme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(vm.kind == kind ? Theme.primary : Theme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionLabel(text: "Periodo")
                Picker("Periodo", selection: $vm.optionIndex) {
                    ForEach(Array(vm.kind.options.enumerated()), id: \.offset) { index, option in
                        Text(option.label).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.primaryLight)
                .frame(maxWidth: .infinity, alignment: .leading)

                SectionLabel(text: "Año")
                Picker("Año", selection: $vm.year) {
                    ForEach(vm.years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.primaryLight)
                .frame(maxWidth: .infinity, alignment: .leading)

                PrimaryButton(title: "Generar informe", isLoading: vm.isLoading) {
                    Task { await vm.generate() }
                }
            }
        }
    }

    // MARK: - Resultados

    private func summaryCard(_ report: PeriodReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "\(vm.option.label) \(String(vm.year)) — \(report.monthCount) mes\(report.monthCount == 1 ? "" : "es")")

                HStack(spacing: 8) {
                    stat(report.totalIncome.currencyString, "Ingresos totales", Theme.success)
                    Divider().frame(height: 34).overlay(Theme.border)
                    stat("-\(report.totalExpenses.currencyString)", "Gastos totales", Theme.danger)
                    Divider().frame(height: 34).overlay(Theme.border)
                    stat(report.balance.currencyString, "Balance", Theme.balanceColor(report.balance))
                }

                HStack(spacing: 8) {
                    boxedStat(report.avgMonthlyIncome.currencyString, "Media ingresos", Theme.warning)
                    boxedStat(report.avgMonthlyExpenses.currencyString, "Media gastos", Theme.danger)
                    boxedStat("\(report.savingsRate) %", "Tasa ahorro", Theme.savingsColor(report.savingsRate))
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(17))
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func boxedStat(_ value: String, _ label: String, _ color: Color) -> some View {
        stat(value, label, color)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func trendCard(_ report: PeriodReport) -> some View {
        let trend = report.monthlyTrend ?? []
        if !trend.isEmpty {
            let maxIncome = trend.map(\.income).max() ?? 0

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Evolución mensual")
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(trend) { point in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(point.month.capitalized)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textBody)
                                    Spacer()
                                    Text(point.balance.signedCurrencyString(positive: point.balance >= 0))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.balanceColor(point.balance))
                                }
                                ProgressBar(value: maxIncome > 0 ? (point.income / maxIncome).doubleValue : 0,
                                            color: Theme.success.opacity(0.75), height: 6)
                                ProgressBar(value: maxIncome > 0 ? (point.expenses / maxIncome).doubleValue : 0,
                                            color: Theme.danger.opacity(0.75), height: 6)
                            }
                        }

                        HStack(spacing: 16) {
                            Label("Ingresos", systemImage: "square.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.success)
                            Label("Gastos", systemImage: "square.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownCard(_ report: PeriodReport) -> some View {
        let categories = report.categoryBreakdown ?? []
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Gastos por categoría")
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(categories) { item in
                            VStack(spacing: 5) {
                                HStack {
                                    Text(item.category)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textBody)
                                    Spacer()
                                    Text("\(item.amount.currencyString) (\(item.pct) %)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.danger)
                                }
                                ProgressBar(value: Double(item.pct) / 100,
                                            color: ExpenseCategory.color(for: item.category))
                            }
                        }
                    }
                }
            }
        }
    }
}
