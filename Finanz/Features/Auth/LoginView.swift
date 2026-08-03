import SwiftUI

/// Puerto de `LoginPage.jsx`: pestañas Entrar / Registro, login con email y
/// contraseña, y acceso con Google o GitHub vía OAuth2 del backend.
struct LoginView: View {

    enum Mode: String, CaseIterable {
        case login = "Entrar"
        case register = "Registro"
    }

    var onForgotPassword: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSettings = false

    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, password.count >= 6 else { return false }
        if mode == .register { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                card
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .finanzBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.textMuted)
                }
                .accessibilityLabel("Configuración del servidor")
            }
        }
        .sheet(isPresented: $showSettings) {
            ServerSettingsView()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(spacing: 6) {
            Text("💸").font(.system(size: 48))
            Text("Finanz")
                .font(.display(28))
                .foregroundStyle(Theme.textPrimary)
            Text("Tu dinero, bajo control total")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.top, 40)
        .padding(.bottom, 32)
    }

    private var card: some View {
        Card(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                modePicker

                if mode == .register {
                    FieldLabel(text: "NOMBRE")
                    TextField("Tu nombre", text: $name)
                        .textFieldStyle(DarkTextFieldStyle())
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                FieldLabel(text: "EMAIL")
                TextField("tu@email.com", text: $email)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()

                FieldLabel(text: "CONTRASEÑA")
                SecureField("••••••••", text: $password)
                    .textFieldStyle(DarkTextFieldStyle())
                    .textContentType(mode == .login ? .password : .newPassword)

                PrimaryButton(title: mode == .login ? "Iniciar sesión" : "Crear cuenta",
                              isLoading: isLoading,
                              isEnabled: canSubmit) {
                    Task { await submit() }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if mode == .login {
                    Button("¿Olvidaste tu contraseña?", action: onForgotPassword)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                divider
                oauthButton(.google)
                oauthButton(.github)
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        mode = option
                        errorMessage = ""
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(mode == option ? .white : Theme.textMuted)
                        .background(mode == option ? Theme.primary : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.bottom, 6)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Text("o continúa con")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize()
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    private func oauthButton(_ provider: OAuthProvider) -> some View {
        Button {
            Task { await signInWithOAuth(provider) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: provider == .google ? "globe" : "chevron.left.forwardslash.chevron.right")
                Text(provider.title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Theme.textPrimary)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Acciones

    private func submit() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let response: AuthResponse
            if mode == .login {
                response = try await AuthService.login(email: email.trimmed, password: password)
            } else {
                response = try await AuthService.register(name: name.trimmed,
                                                          email: email.trimmed,
                                                          password: password)
            }
            session.signIn(token: response.token, user: response.user)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func signInWithOAuth(_ provider: OAuthProvider) async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let callback = try await WebAuthenticator.shared.authenticate(
                url: AuthService.oauthURL(for: provider),
                callbackScheme: AppConfig.oauthCallbackScheme
            )
            guard let token = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value else {
                errorMessage = "El servidor no devolvió ningún token."
                return
            }
            try await session.signIn(withToken: token)
        } catch is WebAuthenticator.Cancelled {
            // El usuario cerró el navegador: no es un error que mostrar.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
