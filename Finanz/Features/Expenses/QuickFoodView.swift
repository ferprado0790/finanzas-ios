import SwiftUI

/// Alta rápida de comida preparada: restaurante, bar o app de reparto.
///
/// La idea es que solo haya que teclear el importe. El sitio se elige de los
/// atajos o de "los de siempre", que los calcula el backend a partir de lo que
/// ya has gastado en la categoría.
struct QuickFoodView: View {

    var onSaved: (Expense) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var place = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var frequent: [FrequentExpense] = []
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var probe = SpendAlertProbe()

    private var amount: Decimal? {
        guard let value = Decimal.parse(amountText), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool { !place.trimmed.isEmpty && amount != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Va a Restaurantes. Elige el sitio y pon el importe.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)

                    if !frequent.isEmpty { frequentSection }

                    SectionLabel(text: "Atajos")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Catalogs.foodPlaces, id: \.self) { shortcut in
                                SelectableChip(title: shortcut,
                                               isSelected: place == shortcut,
                                               accent: Theme.warning) {
                                    place = shortcut
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    FieldLabel(text: "Sitio")
                    TextField("Ej: Glovo, El Rincón", text: $place)
                        .textFieldStyle(DarkTextFieldStyle())

                    FieldLabel(text: "Importe (€)")
                    TextField("0,00", text: $amountText)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.decimalPad)

                    FieldLabel(text: "Fecha")
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, AppConfig.locale)

                    // Aviso en vivo: si estaba previsto y si hay presupuesto.
                    if let alert = probe.alert {
                        SpendAlertBanner(alert: alert)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    PrimaryButton(title: amount.map { "Apuntar \($0.currencyString)" } ?? "Apuntar gasto",
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
            .navigationTitle("🍽️ Comida preparada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .task {
            // Si falla, quedan los atajos fijos: no merece un mensaje de error.
            frequent = (try? await ExpenseService.frequent(category: Catalogs.foodCategory)) ?? []
        }
        .task(id: "\(amountText)|\(place)|\(date.timeIntervalSince1970)") {
            await probe.refresh(amount: amount,
                                description: place,
                                category: Catalogs.foodCategory,
                                date: date)
        }
    }

    private var frequentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Los de siempre")

            ForEach(frequent) { item in
                Button {
                    place = item.description
                    amountText = "\(item.lastAmount)"
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textBody)
                                .lineLimit(1)
                            Text("\(item.timesUsed) veces · media \(item.averageAmount.currencyString)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                        }
                        Spacer(minLength: 4)
                        Text(item.lastAmount.currencyString)
                            .font(.display(13, weight: .semibold))
                            .foregroundStyle(Theme.primaryLight)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() async {
        guard let amount else { return }
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let request = ExpenseRequest(
            description: place.trimmed,
            amount: amount,
            category: Catalogs.foodCategory,
            date: date,
            frequency: "Puntual",
            notes: nil
        )

        do {
            onSaved(try await ExpenseService.create(request))
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
