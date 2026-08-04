import SwiftUI

/// Puerto de `ExpensePage.jsx`: total del mes, desglose por categoría,
/// filtro por categoría y lista de gastos con alta, edición y borrado.
struct ExpenseView: View {

    @State private var vm = ExpenseViewModel()
    @State private var showForm = false
    @State private var showQuickFood = false
    @State private var editingExpense: Expense?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonthSelector(month: $vm.month, year: $vm.year, accent: Theme.danger)

                    Text("-\(vm.total.currencyString)")
                        .font(.display(34))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await vm.load() }
                        }
                    }

                    if !vm.suggestions.isEmpty { recurringSuggestions }

                    categoryFilters
                    categoryBars
                    expenseList

                    Button {
                        editingExpense = nil
                        showForm = true
                    } label: {
                        Text("+ Registrar gasto")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Theme.dangerGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Button {
                        showQuickFood = true
                    } label: {
                        Text("🍽️ Comida preparada (rápido)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Theme.warning)
                            .background(Theme.warning.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .finanzBackground()
            .navigationTitle("Control de gastos")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task(id: "\(vm.month)-\(vm.year)") {
            await vm.load()
            await vm.loadSuggestions()
        }
        .sheet(isPresented: $showForm) {
            ExpenseFormView(expense: editingExpense) { saved in
                vm.upsert(saved)
                Task {
                    await vm.load()
                    await vm.loadSuggestions()
                }
            }
        }
        .sheet(isPresented: $showQuickFood) {
            QuickFoodView { saved in
                vm.upsert(saved)
                Task { await vm.load() }
            }
        }
    }

    // MARK: - Secciones

    /// Gastos fijos que tocan este mes y aún no están apuntados. La gracia es
    /// poder meterlos todos de un toque en vez de volver a teclearlos.
    private var recurringSuggestions: some View {
        Card(borderColor: Theme.warning.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gastos fijos de este mes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(vm.suggestions.count) sin apuntar · \(vm.suggestionsTotal.currencyString)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 0)
                }

                ForEach(vm.suggestions) { suggestion in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textBody)
                                .lineLimit(1)
                            Text("\(suggestion.category) · \(suggestion.frequency) · \(suggestion.occurrences) veces")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(suggestion.amount.currencyString)
                            .font(.display(13, weight: .semibold))
                            .foregroundStyle(Theme.warning)

                        Button {
                            Task { await vm.applySuggestions(seriesIds: [suggestion.seriesId]) }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.success)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isApplyingSuggestions)
                        .accessibilityLabel("Añadir \(suggestion.description)")

                        Button {
                            Task { await vm.dismissSeries(suggestion.seriesId) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isApplyingSuggestions)
                        .accessibilityLabel("No proponer \(suggestion.description)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    Task { await vm.applySuggestions() }
                } label: {
                    Text(vm.isApplyingSuggestions
                         ? "Añadiendo…"
                         : "Añadir todos (\(vm.suggestionsTotal.currencyString))")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Theme.warning)
                        .background(Theme.warning.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(vm.isApplyingSuggestions)
            }
        }
    }

    private var categoryFilters: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Por categoría")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectableChip(title: "Todas",
                                   isSelected: vm.filterCategory == "Todas",
                                   accent: Theme.danger) {
                        vm.filterCategory = "Todas"
                    }
                    ForEach(vm.categoryTotals, id: \.category.id) { entry in
                        SelectableChip(title: entry.category.name,
                                       isSelected: vm.filterCategory == entry.category.name,
                                       accent: Theme.danger) {
                            vm.filterCategory = entry.category.name
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var categoryBars: some View {
        let top = Array(vm.categoryTotals.prefix(5))
        if let maxTotal = top.first?.total, maxTotal > 0 {
            Card {
                VStack(spacing: 12) {
                    ForEach(top, id: \.category.id) { entry in
                        VStack(spacing: 5) {
                            HStack {
                                Label(entry.category.name, systemImage: entry.category.symbol)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textBody)
                                Spacer()
                                Text(entry.total.currencyString)
                                    .font(.display(13, weight: .semibold))
                                    .foregroundStyle(entry.category.color)
                            }
                            ProgressBar(value: (entry.total / maxTotal).doubleValue,
                                        color: entry.category.color.opacity(0.75))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "\(vm.filterCategory == "Todas" ? "Todos los gastos" : vm.filterCategory) — \(vm.filteredTotal.currencyString)")

            if vm.isLoading && vm.expenses.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if vm.filtered.isEmpty {
                EmptyStateView(icon: "tray",
                               title: "Sin gastos en este periodo",
                               subtitle: "Pulsa «Registrar gasto» para añadir el primero.")
            } else {
                ForEach(vm.filtered) { expense in
                    ExpenseRow(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingExpense = expense
                            showForm = true
                        }
                        .contextMenu {
                            Button("Editar") {
                                editingExpense = expense
                                showForm = true
                            }
                            Button("Eliminar", role: .destructive) {
                                Task { await vm.delete(expense) }
                            }
                        }
                }
            }
        }
    }
}

/// Fila de gasto con icono de categoría, importe y acción de borrado.
struct ExpenseRow: View {

    let expense: Expense

    private var category: ExpenseCategory { ExpenseCategory.find(expense.category) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.color.opacity(0.15))
                Image(systemName: category.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(category.color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textBody)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(expense.category) · \(Formatters.shortDate.string(from: expense.date))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    if let frequency = expense.frequency, frequency != "Puntual" {
                        Text(frequency)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.15))
                            .foregroundStyle(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer(minLength: 4)

            Text("-\(expense.amount.currencyString)")
                .font(.display(15, weight: .bold))
                .foregroundStyle(Theme.danger)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
