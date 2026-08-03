import SwiftUI

/// Alta y edición de ingreso. Carga sola la lista de trabajos, así puede
/// abrirse tanto desde Ingresos como desde los accesos rápidos del Inicio.
struct IncomeFormView: View {

    var income: Income?
    var onSaved: (Income) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var jobs: [Job] = []
    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var selectedJobId: Int64?
    @State private var date = Date()
    @State private var recurring = false
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool {
        !descriptionText.trimmed.isEmpty && (Decimal.parse(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FieldLabel(text: "Descripción")
                    TextField("Ej: Nómina de junio", text: $descriptionText)
                        .textFieldStyle(DarkTextFieldStyle())

                    FieldLabel(text: "Importe (€)")
                    TextField("0,00", text: $amountText)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.decimalPad)

                    FieldLabel(text: "Trabajo asociado")
                    Picker("Trabajo", selection: $selectedJobId) {
                        Text("Sin trabajo específico").tag(Int64?.none)
                        ForEach(jobs) { job in
                            Text(job.name).tag(Int64?.some(job.id))
                        }
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

                    FieldLabel(text: "Fecha")
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, AppConfig.locale)

                    Toggle(isOn: $recurring) {
                        Text("Ingreso recurrente (se repite cada mes)")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textBody)
                    }
                    .tint(Theme.primary)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    PrimaryButton(title: "Guardar", isLoading: isSaving, isEnabled: isValid) {
                        Task { await save() }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .finanzBackground()
            .navigationTitle(income == nil ? "Registrar ingreso" : "Editar ingreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .task {
            jobs = (try? await JobService.all()) ?? []
            if let income {
                descriptionText = income.description
                amountText = "\(income.amount)"
                selectedJobId = income.jobId
                date = income.date
                recurring = income.recurring
            }
        }
    }

    private func save() async {
        guard let amount = Decimal.parse(amountText), amount > 0 else { return }
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let request = IncomeRequest(description: descriptionText.trimmed,
                                    amount: amount,
                                    jobId: selectedJobId,
                                    date: date,
                                    recurring: recurring)
        do {
            let saved: Income
            if let income {
                saved = try await IncomeService.update(id: income.id, request)
            } else {
                saved = try await IncomeService.create(request)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
