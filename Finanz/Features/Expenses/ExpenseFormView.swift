import SwiftUI

/// Alta y edición de gasto (el modal de `ExpensePage.jsx`).
struct ExpenseFormView: View {

    var expense: Expense?
    var onSaved: (Expense) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var category = "Alimentación"
    @State private var frequency = "Puntual"
    @State private var date = Date()
    @State private var notes = ""
    /// Meses siguientes en los que dejarlo creado; 0 = solo este.
    @State private var replicateMonths = 0
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var probe = SpendAlertProbe()

    private var isValid: Bool {
        !descriptionText.trimmed.isEmpty && (Decimal.parse(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FieldLabel(text: "Descripción")
                    TextField("Ej: Supermercado", text: $descriptionText)
                        .textFieldStyle(DarkTextFieldStyle())

                    FieldLabel(text: "Importe (€)")
                    TextField("0,00", text: $amountText)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.decimalPad)

                    FieldLabel(text: "Categoría")
                    categoryGrid

                    FieldLabel(text: "Frecuencia")
                    Picker("Frecuencia", selection: $frequency) {
                        ForEach(Catalogs.frequencies, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: frequency) { _, newValue in
                        if newValue == "Puntual" { replicateMonths = 0 }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.primaryLight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                    // Un gasto fijo se deja creado de una vez en los meses que
                    // vienen, en lugar de volver a apuntarlo cada mes.
                    if frequency != "Puntual" {
                        FieldLabel(text: "Dejarlo creado también en los próximos meses")
                        HStack(spacing: 8) {
                            ForEach([0, 3, 6, 12], id: \.self) { months in
                                SelectableChip(title: months == 0 ? "Solo este" : "\(months) meses",
                                               isSelected: replicateMonths == months,
                                               accent: Theme.warning) {
                                    replicateMonths = months
                                }
                            }
                        }
                    }

                    FieldLabel(text: "Fecha")
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, AppConfig.locale)

                    FieldLabel(text: "Notas (opcional)")
                    TextField("Notas adicionales…", text: $notes)
                        .textFieldStyle(DarkTextFieldStyle())

                    // Aviso en vivo: si estaba previsto y si hay presupuesto.
                    // Solo informa; nunca impide guardar.
                    if let alert = probe.alert {
                        SpendAlertBanner(alert: alert)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    PrimaryButton(title: expense == nil ? "Guardar gasto" : "Guardar cambios",
                                  gradient: Theme.dangerGradient,
                                  isLoading: isSaving,
                                  isEnabled: isValid) {
                        Task { await save() }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .finanzBackground()
            .navigationTitle(expense == nil ? "Nuevo gasto" : "Editar gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .onAppear(perform: preload)
        .task(id: "\(amountText)|\(descriptionText)|\(category)|\(date.timeIntervalSince1970)") {
            await probe.refresh(amount: Decimal.parse(amountText),
                                description: descriptionText,
                                category: category,
                                date: date)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(ExpenseCategory.all) { cat in
                Button {
                    category = cat.name
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: cat.symbol)
                            .font(.system(size: 17))
                        Text(cat.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(category == cat.name ? cat.color : Theme.textMuted)
                    .background(category == cat.name ? cat.color.opacity(0.2) : Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(category == cat.name ? cat.color : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func preload() {
        guard let expense else { return }
        descriptionText = expense.description
        amountText = "\(expense.amount)"
        category = expense.category
        frequency = expense.frequency ?? "Puntual"
        date = expense.date
        notes = expense.notes ?? ""
    }

    private func save() async {
        guard let amount = Decimal.parse(amountText), amount > 0 else { return }
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let request = ExpenseRequest(
            description: descriptionText.trimmed,
            amount: amount,
            category: category,
            date: date,
            frequency: frequency,
            notes: notes.trimmed.isEmpty ? nil : notes.trimmed
        )

        do {
            let saved: Expense
            if let expense {
                saved = try await ExpenseService.update(id: expense.id, request)
            } else {
                saved = try await ExpenseService.create(request)
            }
            // Las copias son un extra: si fallan, el gasto ya está guardado.
            if replicateMonths > 0 {
                _ = try? await ExpenseService.replicate(id: saved.id, months: replicateMonths)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
