import SwiftUI
import Observation

/// Periodo de referencia para el análisis del gasto.
enum ReferencePeriod: String, CaseIterable, Identifiable {
    case current = "Mes actual"
    case quarter = "Últimos 3 meses"
    case semester = "Últimos 6 meses"
    case year = "Últimos 12 meses"

    var id: String { rawValue }

    /// Meses hacia atrás desde el mes actual (nil = solo el mes actual).
    var monthsBack: Int? {
        switch self {
        case .current: return nil
        case .quarter: return 2
        case .semester: return 5
        case .year: return 11
        }
    }

    /// Rango (desde, hasta) en formato (mes, año) que espera el backend.
    var range: (from: (month: Int, year: Int), to: (month: Int, year: Int))? {
        guard let monthsBack else { return nil }
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .month, value: -monthsBack, to: now) else { return nil }
        return (from: (start.monthComponent, start.yearComponent),
                to: (now.monthComponent, now.yearComponent))
    }
}

@MainActor
@Observable
final class BudgetCheckViewModel {

    var amountText = ""
    var category = "Ocio"
    var period: ReferencePeriod = .current

    private(set) var summary: BudgetSummary?
    private(set) var limits: [BudgetLimit] = []
    private(set) var result: CheckExpenseResult?
    private(set) var isChecking = false
    var errorMessage: String?

    var amount: Decimal? {
        guard let value = Decimal.parse(amountText), value > 0 else { return nil }
        return value
    }

    func load() async {
        let month = Date().monthComponent
        let year = Date().yearComponent
        do {
            async let summaryTask = BudgetService.summary(month: month, year: year)
            async let limitsTask = BudgetService.limits()
            let (loadedSummary, loadedLimits) = try await (summaryTask, limitsTask)
            summary = loadedSummary
            limits = loadedLimits
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func check() async {
        guard let amount else { return }
        isChecking = true
        errorMessage = nil
        result = nil

        let range = period.range
        let request = CheckExpenseRequest(
            amount: amount,
            category: category,
            fromMonth: range?.from.month,
            fromYear: range?.from.year,
            toMonth: range?.to.month,
            toYear: range?.to.year
        )

        do {
            result = try await BudgetService.checkExpense(request)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isChecking = false
    }

    func saveLimit(category: String, limit: Decimal) async {
        do {
            let saved = try await BudgetService.setLimit(category: category, limit: limit)
            if let index = limits.firstIndex(where: { $0.category == saved.category }) {
                limits[index] = saved
            } else {
                limits.append(saved)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Puerto de `BudgetCheckPage.jsx`: «¿Puedo permitirme este gasto?».
struct BudgetCheckView: View {

    @State private var vm = BudgetCheckViewModel()
    @State private var showLimitForm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Introduce el importe y te diré si es seguro gastarlo según tu situación actual.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)

                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await vm.load() }
                        }
                    }

                    if let summary = vm.summary {
                        currentSituation(summary)
                    }

                    inputCard

                    if let result = vm.result {
                        resultCard(result)
                    }

                    limitsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .finanzBackground()
            .navigationTitle("¿Puedo gastarlo?")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showLimitForm) {
            BudgetLimitFormView { category, limit in
                Task { await vm.saveLimit(category: category, limit: limit) }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Secciones

    private func currentSituation(_ summary: BudgetSummary) -> some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Tu situación actual")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Balance libre")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                        Text(summary.balance.currencyString)
                            .font(.display(18))
                            .foregroundStyle(Theme.balanceColor(summary.balance))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Ahorro")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                        Text("\(summary.savingsRate) %")
                            .font(.display(18))
                            .foregroundStyle(Theme.savingsColor(summary.savingsRate))
                    }
                }
            }
        }
    }

    private var inputCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                FieldLabel(text: "Importe del gasto (€)")
                TextField("0,00", text: $vm.amountText)
                    .font(.display(26))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(DarkTextFieldStyle())

                FieldLabel(text: "Periodo de referencia")
                FlowChips(items: ReferencePeriod.allCases.map(\.rawValue),
                          selection: vm.period.rawValue) { value in
                    if let match = ReferencePeriod(rawValue: value) { vm.period = match }
                }

                FieldLabel(text: "Categoría")
                FlowChips(items: Catalogs.budgetCategories, selection: vm.category) { value in
                    vm.category = value
                }

                PrimaryButton(title: "Analizar gasto",
                              isLoading: vm.isChecking,
                              isEnabled: vm.amount != nil) {
                    Task { await vm.check() }
                }
            }
        }
    }

    private func resultCard(_ result: CheckExpenseResult) -> some View {
        let accent: Color = result.approved ? Theme.success : (result.canAfford ? Theme.warning : Theme.danger)
        let icon = result.approved ? "checkmark.circle.fill" : (result.canAfford ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
        let title = result.approved ? "¡Aprobado!" : (result.canAfford ? "Con precaución" : "No recomendado")

        return Card(padding: 20, borderColor: accent, borderWidth: 2) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 42))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.display(21))
                        .foregroundStyle(accent)
                    Text(result.message)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textBody)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    resultMetric("Balance restante",
                                 result.remainingAfter.currencyString,
                                 Theme.balanceColor(result.remainingAfter))
                    resultMetric("Nuevo ahorro",
                                 "\(result.newSavingsRate) %",
                                 Theme.savingsColor(result.newSavingsRate))
                }

                if let suggestions = result.suggestions, !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Sugerencias")
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                    .padding(.top, 3)
                                Text(suggestion)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textBody)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private func resultMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(.display(18))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Límites mensuales")

            if vm.limits.isEmpty {
                Text("Aún no has definido límites por categoría.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(vm.limits) { limit in
                Card(padding: 14) {
                    VStack(spacing: 8) {
                        HStack {
                            Text(limit.category)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textBody)
                            Spacer()
                            Text("\(limit.spent.currencyString) / \(limit.limit.currencyString)")
                                .font(.system(size: 13))
                                .foregroundStyle(limit.pct > 90 ? Theme.danger : Theme.textMuted)
                        }
                        ProgressBar(value: Double(limit.pct) / 100,
                                    color: limit.pct > 90 ? Theme.danger : (limit.pct > 70 ? Theme.warning : Theme.success))
                    }
                }
            }

            Button {
                showLimitForm = true
            } label: {
                Text("+ Añadir límite de categoría")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Theme.textMuted)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

/// Fila de chips que salta de línea, como los filtros de la web.
struct FlowChips: View {
    let items: [String]
    let selection: String
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                SelectableChip(title: item, isSelected: selection == item) {
                    onSelect(item)
                }
            }
        }
    }
}

/// Alta / actualización de límite mensual por categoría.
struct BudgetLimitFormView: View {

    var onSave: (String, Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category = Catalogs.budgetCategories[1]
    @State private var limitText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                FieldLabel(text: "Categoría")
                Picker("Categoría", selection: $category) {
                    ForEach(Catalogs.budgetCategories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.primaryLight)
                .frame(maxWidth: .infinity, alignment: .leading)

                FieldLabel(text: "Límite mensual (€)")
                TextField("0,00", text: $limitText)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.decimalPad)

                PrimaryButton(title: "Guardar límite",
                              isEnabled: (Decimal.parse(limitText) ?? 0) > 0) {
                    if let value = Decimal.parse(limitText), value > 0 {
                        onSave(category, value)
                        dismiss()
                    }
                }

                Spacer()
            }
            .padding(20)
            .finanzBackground()
            .navigationTitle("Nuevo límite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }
}
