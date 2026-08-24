import SwiftUI

/// Conexión con el banco: vincular, renovar el permiso y ajustar qué se apunta solo.
struct BankView: View {

    @State private var vm = BankViewModel()
    @State private var showingPicker = false
    @State private var connectionToUnlink: BankConnection?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if let error = vm.errorMessage {
                    ErrorBanner(message: error) { Task { await vm.load() } }
                }
                if let info = vm.infoMessage {
                    infoBanner(info)
                }

                if !vm.status.available {
                    unavailableCard
                } else {
                    if vm.status.pendingMovements > 0 { pendingCard }

                    ForEach(vm.status.connections) { connection in
                        ConnectionCard(
                            connection: connection,
                            isSyncing: vm.syncingConnectionId == connection.id,
                            onSync: { Task { await vm.sync(connection: connection) } },
                            onRenew: { Task { await vm.renew(connection: connection) } },
                            onAutoConfirm: { value in
                                Task { await vm.setAutoConfirm(connection: connection, enabled: value) }
                            },
                            onAccountToggle: { account, value in
                                Task {
                                    await vm.setAccountSync(connection: connection,
                                                            account: account, enabled: value)
                                }
                            },
                            onUnlink: { connectionToUnlink = connection })
                    }

                    if !vm.hasConnections { explainerCard }

                    PrimaryButton(title: vm.hasConnections ? "Conectar otro banco" : "Conectar mi banco",
                                  isLoading: vm.isLinking) {
                        showingPicker = true
                    }

                    privacyNote
                }
            }
            .padding(20)
        }
        .finanzBackground()
        .navigationTitle("Mi banco")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.refreshQuietly() }
        .task { await vm.load() }
        // Red de seguridad. Lo normal es que la autorización vuelva dentro de
        // `ASWebAuthenticationSession`, pero si el banco abre su propia app y
        // se rompe esa sesión, la vuelta a la app deja la pantalla desfasada.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.refreshQuietly() } }
        }
        .sheet(isPresented: $showingPicker) {
            InstitutionPickerView(vm: vm) { institution in
                showingPicker = false
                Task { await vm.link(institution: institution) }
            }
        }
        // Con `.constant(...)` SwiftUI no puede cerrar el diálogo al deslizar
        // fuera: hay que darle un enlace que también sepa escribir.
        .confirmationDialog("¿Desconectar el banco?",
                            isPresented: Binding(get: { connectionToUnlink != nil },
                                                 set: { if !$0 { connectionToUnlink = nil } }),
                            titleVisibility: .visible) {
            Button("Desconectar", role: .destructive) {
                if let connection = connectionToUnlink {
                    connectionToUnlink = nil
                    Task { await vm.unlink(connection: connection) }
                }
            }
            Button("Cancelar", role: .cancel) { connectionToUnlink = nil }
        } message: {
            Text("Dejarán de llegar movimientos nuevos. Los gastos que ya apuntaste no se tocan.")
        }
    }

    // MARK: - Bloques

    private var pendingCard: some View {
        NavigationLink {
            CardMovementsView(vm: vm)
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.warning)
                        .frame(width: 36, height: 36)
                        .background(Theme.warning.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.status.pendingMovements == 1
                             ? "1 gasto sin repasar"
                             : "\(vm.status.pendingMovements) gastos sin repasar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Todavía no cuentan en el presupuesto")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var explainerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Qué hace esto")
                bullet("creditcard.fill",
                       "Los pagos con tarjeta aparecen solos, también los que hagas con el móvil: para el banco es la misma tarjeta.")
                bullet("iphone.gen3",
                       "Los Bizum y los recibos domiciliados también.")
                bullet("hand.raised.fill",
                       "Nada se apunta sin que tú lo confirmes, salvo que actives la confirmación automática.")
            }
        }
    }

    private var unavailableCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "No disponible")
                Text("El servidor no tiene configurada la conexión con el banco.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textBody)
                Text("Hacen falta GOCARDLESS_SECRET_ID y GOCARDLESS_SECRET_KEY en el archivo .env del servidor.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    /// Merece decirlo explícitamente: es la duda razonable de cualquiera antes
    /// de conectar su banco a una app.
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.success)
            Text("Te autenticas en la web de tu banco. Ni esta app ni el intermediario ven tus claves, y el permiso es de solo lectura: nadie puede mover dinero.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.top, 2)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.primaryLight)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textBody)
        }
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.info)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textBody)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.info.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Tarjeta de una vinculación

private struct ConnectionCard: View {

    let connection: BankConnection
    let isSyncing: Bool
    let onSync: () -> Void
    let onRenew: () -> Void
    let onAutoConfirm: (Bool) -> Void
    let onAccountToggle: (BankAccount, Bool) -> Void
    let onUnlink: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.primaryLight)
                        .frame(width: 36, height: 36)
                        .background(Theme.primary.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.institutionName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(connection.statusText)
                            .font(.system(size: 12))
                            .foregroundStyle(connection.needsRenewal ? Theme.danger
                                             : connection.isLinked ? Theme.success : Theme.textMuted)
                    }
                    Spacer(minLength: 0)

                    if isSyncing {
                        ProgressView().controlSize(.small)
                    } else if connection.isLinked && !connection.needsRenewal {
                        Button(action: onSync) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 30)
                                .foregroundStyle(Theme.textBody)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Buscar movimientos nuevos")
                    }
                }

                if let warning = connection.expiryWarning {
                    Text(warning)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.warning)
                }
                if let error = connection.lastSyncError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }
                if let last = connection.lastSyncAt {
                    Text("Última consulta: \(Formatters.mediumDate.string(from: last))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }

                if connection.needsRenewal || connection.status == "PENDING" {
                    Button(action: onRenew) {
                        Text(connection.status == "PENDING" ? "Terminar la autorización" : "Renovar permiso")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(Theme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if connection.isLinked {
                    Divider().overlay(Theme.border)

                    Toggle(isOn: Binding(get: { connection.autoConfirm },
                                         set: { onAutoConfirm($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apuntar los gastos solos")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textBody)
                            Text("Sin repasarlos, con la categoría que adivine la app")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    .tint(Theme.primary)

                    if !connection.accounts.isEmpty {
                        ForEach(connection.accounts) { account in
                            Toggle(isOn: Binding(get: { account.syncEnabled },
                                                 set: { onAccountToggle(account, $0) })) {
                                Text("\(account.name ?? "Cuenta") \(account.maskedIban)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .tint(Theme.primary)
                        }
                    }
                }

                Button(role: .destructive, action: onUnlink) {
                    Text("Desconectar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
