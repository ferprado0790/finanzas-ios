import SwiftUI

/// Puerto de `ForgotPasswordPage.jsx`.
struct ForgotPasswordView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("🔑").font(.system(size: 44))
                        Text("Recuperar cuenta")
                            .font(.display(24))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Te enviaremos un enlace para restablecer tu contraseña")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    Card(padding: 22) {
                        if sent {
                            VStack(spacing: 14) {
                                Text("✅ Correo enviado a \(email).\nRevisa tu bandeja de entrada y abre el enlace.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: 0x4ADE80))
                                    .multilineTextAlignment(.center)
                                Button("Volver al inicio de sesión") { dismiss() }
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                FieldLabel(text: "EMAIL")
                                TextField("tu@email.com", text: $email)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.send)
                                    .onSubmit { Task { await send() } }

                                PrimaryButton(title: "Enviar enlace",
                                              isLoading: isLoading,
                                              isEnabled: !email.trimmed.isEmpty) {
                                    Task { await send() }
                                }

                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.danger)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .finanzBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    private func send() async {
        guard !email.trimmed.isEmpty else { return }
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.forgotPassword(email: email.trimmed)
            sent = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
