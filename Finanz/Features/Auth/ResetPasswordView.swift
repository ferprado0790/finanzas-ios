import SwiftUI

/// Puerto de `ResetPasswordPage.jsx`. Se abre cuando la app recibe el deep link
/// `finanz://reset?token=<token>` desde el correo de recuperación.
struct ResetPasswordView: View {

    let resetToken: String

    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var done = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("🔒").font(.system(size: 44))
                        Text("Nueva contraseña")
                            .font(.display(24))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Elige una contraseña segura para tu cuenta")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.top, 24)

                    Card(padding: 22) {
                        if done {
                            VStack(spacing: 14) {
                                Text("✅ Contraseña actualizada correctamente.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: 0x4ADE80))
                                PrimaryButton(title: "Iniciar sesión") { dismiss() }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                FieldLabel(text: "NUEVA CONTRASEÑA")
                                SecureField("Mínimo 6 caracteres", text: $password)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.newPassword)

                                FieldLabel(text: "CONFIRMAR CONTRASEÑA")
                                SecureField("Repite la contraseña", text: $confirmation)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .textContentType(.newPassword)

                                PrimaryButton(title: "Cambiar contraseña",
                                              isLoading: isLoading,
                                              isEnabled: password.count >= 6) {
                                    Task { await submit() }
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

    private func submit() async {
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres"
            return
        }
        guard password == confirmation else {
            errorMessage = "Las contraseñas no coinciden"
            return
        }
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.resetPassword(token: resetToken, newPassword: password)
            done = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
