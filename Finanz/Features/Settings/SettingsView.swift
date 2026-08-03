import SwiftUI

/// Ajustes de la sesión iniciada: perfil, servidor y cierre de sesión.
/// El backend expone `PATCH /api/auth/me`, así que la edición de perfil es real.
struct SettingsView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var message = ""
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "Perfil")

                            FieldLabel(text: "Nombre")
                            TextField("Tu nombre", text: $name)
                                .textFieldStyle(DarkTextFieldStyle())

                            FieldLabel(text: "Email")
                            TextField("tu@email.com", text: $email)
                                .textFieldStyle(DarkTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            if let provider = session.user?.provider, provider != "LOCAL" {
                                Text("Cuenta vinculada con \(provider.capitalized).")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textMuted)
                            }

                            PrimaryButton(title: "Guardar perfil",
                                          isLoading: isSaving,
                                          isEnabled: !name.trimmed.isEmpty && !email.trimmed.isEmpty) {
                                Task { await saveProfile() }
                            }

                            if !message.isEmpty {
                                Text(message)
                                    .font(.system(size: 13))
                                    .foregroundStyle(messageIsError ? Theme.danger : Theme.success)
                            }
                        }
                    }

                    ServerSettingsCard()

                    Button(role: .destructive) {
                        session.signOut()
                        dismiss()
                    } label: {
                        Text("Cerrar sesión")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(Theme.danger)
                            .background(Theme.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .finanzBackground()
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .onAppear {
            name = session.user?.name ?? ""
            email = session.user?.email ?? ""
        }
    }

    private func saveProfile() async {
        isSaving = true
        message = ""
        defer { isSaving = false }
        do {
            let response = try await AuthService.updateProfile(name: name.trimmed, email: email.trimmed)
            TokenStore.token = response.token
            session.updateUser(response.user)
            messageIsError = false
            message = "Perfil actualizado."
        } catch {
            messageIsError = true
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Configuración de la URL del backend, útil para probar en dispositivo físico
/// (donde `localhost` no apunta al Mac) o contra un túnel.
struct ServerSettingsCard: View {

    @State private var urlText = AppConfig.storedBaseURLString ?? AppConfig.defaultBaseURL
    @State private var saved = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Servidor")

                Text("Dirección del backend. Puedes escribir solo la IP y el puerto: se le añade /api automáticamente.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)

                TextField("192.168.1.100:8081", text: $urlText)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack(spacing: 10) {
                    Button("Guardar") {
                        AppConfig.storedBaseURLString = urlText
                        urlText = AppConfig.baseURL.absoluteString   // ya normalizada
                        saved = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primaryLight)

                    Button("Restaurar") {
                        AppConfig.storedBaseURLString = nil
                        urlText = AppConfig.defaultBaseURL
                        saved = true
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)

                    Spacer()

                    if saved {
                        Text("Guardado")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.success)
                    }
                }
            }
        }
        .onChange(of: urlText) { _, _ in saved = false }
    }
}

/// Versión en hoja para la pantalla de login (aún no hay sesión).
struct ServerSettingsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ServerSettingsCard()
                    .padding(20)
            }
            .finanzBackground()
            .navigationTitle("Servidor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .foregroundStyle(Theme.primaryLight)
                }
            }
        }
    }
}
