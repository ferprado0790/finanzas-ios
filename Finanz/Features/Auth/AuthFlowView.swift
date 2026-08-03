import SwiftUI

/// Contenedor del flujo sin sesión: login / registro, recuperar contraseña y
/// restablecerla (esta última se abre por deep link `finanz://reset?token=…`).
struct AuthFlowView: View {

    @Environment(SessionStore.self) private var session
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            LoginView(onForgotPassword: { showForgotPassword = true })
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { session.pendingResetToken.map(ResetTokenWrapper.init) },
            set: { if $0 == nil { session.pendingResetToken = nil } }
        )) { wrapper in
            ResetPasswordView(resetToken: wrapper.token)
        }
    }
}

/// `sheet(item:)` necesita un `Identifiable`.
struct ResetTokenWrapper: Identifiable {
    let token: String
    var id: String { token }
}
