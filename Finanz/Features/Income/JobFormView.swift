import SwiftUI

/// Alta y edición de trabajo (fuente de ingresos).
struct JobFormView: View {

    var job: Job?
    var onSaved: (Job) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = Catalogs.jobTypes[0]
    @State private var expectedText = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    private var isValid: Bool { !name.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FieldLabel(text: "Nombre del trabajo")
                    TextField("Ej: Trabajo en empresa X", text: $name)
                        .textFieldStyle(DarkTextFieldStyle())

                    FieldLabel(text: "Tipo")
                    Picker("Tipo", selection: $type) {
                        ForEach(Catalogs.jobTypes, id: \.self) { Text($0).tag($0) }
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

                    FieldLabel(text: "Ingreso esperado mensual (€)")
                    TextField("0,00", text: $expectedText)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.decimalPad)

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
            .navigationTitle(job == nil ? "Nuevo trabajo" : "Editar trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .onAppear {
            guard let job else { return }
            name = job.name
            type = job.type
            if let expected = job.expectedMonthly { expectedText = "\(expected)" }
        }
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let request = JobRequest(name: name.trimmed,
                                 type: type,
                                 expectedMonthly: Decimal.parse(expectedText))
        do {
            let saved: Job
            if let job {
                saved = try await JobService.update(id: job.id, request)
            } else {
                saved = try await JobService.create(request)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
