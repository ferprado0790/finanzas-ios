import SwiftUI

/// La bandeja de gastos detectados en el banco.
///
/// Cada fila es un cargo que todavía NO cuenta para el presupuesto. Cuenta
/// cuando se confirma, y por eso el gesto de confirmar tiene que ser de un solo
/// toque: si repasar cuesta, la bandeja se abandona y la función deja de servir.
struct CardMovementsView: View {

    @Bindable var vm: BankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editing: CardMovement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                if let error = vm.errorMessage {
                    ErrorBanner(message: error) { Task { await vm.load() } }
                }
                if let info = vm.infoMessage {
                    infoBanner(info)
                }

                if vm.pending.isEmpty {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "Nada pendiente",
                            subtitle: vm.hasConnections
                                ? "Cuando pagues con la tarjeta, el cargo aparecerá aquí."
                                : "Conecta tu banco en Ajustes para que los gastos lleguen solos.")
                    }
                } else {
                    header
                    ForEach(vm.pending) { movement in
                        MovementRow(
                            movement: movement,
                            isBusy: vm.busyMovementIds.contains(movement.id),
                            onConfirm: { Task { await vm.confirm(movement) } },
                            onIgnore: { Task { await vm.ignore(movement) } },
                            onEdit: { editing = movement })
                    }
                    confirmAllButton
                }
            }
            .padding(20)
        }
        .finanzBackground()
        .navigationTitle("Gastos detectados")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.refreshQuietly() }
        .task { await vm.load() }
        .sheet(item: $editing) { movement in
            MovementCategorySheet(movement: movement) { category in
                editing = nil
                Task { await vm.confirm(movement, category: category) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(vm.pending.count) sin repasar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Suman \(vm.pendingTotal.currencyString). Todavía no cuentan en el presupuesto.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
        }
    }

    private var confirmAllButton: some View {
        VStack(spacing: 6) {
            PrimaryButton(title: "Apuntarlos todos (\(vm.bulkConfirmable.count))",
                          isLoading: vm.isLoading,
                          isEnabled: !vm.bulkConfirmable.isEmpty) {
                Task { await vm.confirmAll() }
            }
            if vm.bulkConfirmable.count < vm.pending.count {
                Text("Las retiradas en cajero se quedan fuera: el gasto real es lo que pagues con ese dinero.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.info)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textBody)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.info.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Fila

private struct MovementRow: View {

    let movement: CardMovement
    let isBusy: Bool
    let onConfirm: () -> Void
    let onIgnore: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: movement.symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(ExpenseCategory.color(for: movement.category))
                        .frame(width: 34, height: 34)
                        .background(ExpenseCategory.color(for: movement.category).opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(movement.merchant)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)

                        if movement.pendingAtBank {
                            Text("Aún sin contabilizar: el importe puede cambiar.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.warning)
                        }
                        if movement.isCashWithdrawal {
                            Text("Sacar dinero no es un gasto en sí. Apunta después en qué se va.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(movement.amount.currencyString)
                        .font(.display(16))
                        .foregroundStyle(Theme.danger)
                }

                HStack(spacing: 8) {
                    // La categoría es un botón, no una etiqueta: cambiarla es lo
                    // primero que se quiere hacer cuando el backend no acierta.
                    Button(action: onEdit) {
                        HStack(spacing: 5) {
                            Text(movement.category)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .foregroundStyle(ExpenseCategory.color(for: movement.category))
                        .background(ExpenseCategory.color(for: movement.category).opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cambiar la categoría de \(movement.merchant)")

                    Spacer(minLength: 0)

                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(action: onIgnore) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, height: 30)
                                .foregroundStyle(Theme.textMuted)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Descartar \(movement.merchant)")

                        Button(action: onConfirm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, height: 30)
                                .foregroundStyle(.white)
                                .background(Theme.primaryGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Apuntar \(movement.merchant)")
                    }
                }
            }
        }
    }

    private var subtitle: String {
        var parts = [Formatters.shortDate.string(from: movement.bookingDate), movement.kindLabel]
        if let account = movement.accountLabel { parts.append(account) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Cambiar categoría

private struct MovementCategorySheet: View {

    let movement: CardMovement
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movement.merchant)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(movement.amount.currencyString + " · "
                                 + Formatters.mediumDate.string(from: movement.bookingDate))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)

                            // El concepto en crudo del banco: cuando el nombre
                            // limpio no basta para reconocer la compra, aquí
                            // está lo que el banco mandó de verdad.
                            if let raw = movement.rawDescription, !raw.isEmpty {
                                Text(raw)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    SectionLabel(text: "Apuntar como")

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                        ForEach(ExpenseCategory.all) { category in
                            Button { onPick(category.name) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.symbol).font(.system(size: 12))
                                    Text(category.name).font(.system(size: 13)).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(category.name == movement.category
                                                 ? category.color : Theme.textBody)
                                .background(category.name == movement.category
                                            ? category.color.opacity(0.13) : Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(category.name == movement.category
                                                ? category.color : Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .finanzBackground()
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Theme.textMuted)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
