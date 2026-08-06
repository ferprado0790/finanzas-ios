import SwiftUI
import Observation
import VisionKit

@MainActor
@Observable
final class ReceiptScannerViewModel {

    private(set) var receipt: Receipt?
    /// Texto del paso en curso ("Leyendo las fotos…"), o nil si no hay ninguno.
    private(set) var busyMessage: String?
    var errorMessage: String?

    /// Abre un ticket a medias, o crea uno nuevo si no se pasa id.
    func start(receiptId: Int64?, manual: Bool) async {
        guard receipt == nil else { return }
        busyMessage = "Preparando el ticket…"
        do {
            if let receiptId {
                receipt = try await ReceiptService.get(id: receiptId)
            } else {
                receipt = try await ReceiptService.create(
                    ReceiptRequest(date: Date(),
                                   category: "Alimentación",
                                   source: manual ? "MANUAL" : "CAMERA")
                )
            }
        } catch {
            report(error)
        }
        busyMessage = nil
    }

    /// Manda el texto de cada foto en orden; el backend acumula las líneas.
    func addPages(_ texts: [String]) async {
        guard let id = receipt?.id else { return }
        await run("Leyendo las fotos…") {
            var latest: Receipt?
            for text in texts {
                latest = try await ReceiptService.addPage(id: id, rawText: text)
            }
            return latest
        }
    }

    func removePage(_ pageIndex: Int) async {
        guard let id = receipt?.id else { return }
        await run("Quitando la foto…") { try await ReceiptService.deletePage(id: id, pageIndex: pageIndex) }
    }

    func addItem(description: String, amount: Decimal) async {
        guard let id = receipt?.id else { return }
        await run("Guardando…") {
            try await ReceiptService.addItem(id: id,
                                             ReceiptItemRequest(description: description, amount: amount))
        }
    }

    func deleteItem(itemId: Int64) async {
        guard let id = receipt?.id else { return }
        await run("Borrando…") { try await ReceiptService.deleteItem(id: id, itemId: itemId) }
    }

    func updateDetails(_ request: ReceiptRequest) async {
        guard let id = receipt?.id else { return }
        await run("Guardando…") { try await ReceiptService.update(id: id, request) }
    }

    /// Repaso de la lista de la compra, disponible tras confirmar.
    private(set) var shoppingCheck: ShoppingCheck?

    /**
     * Cierra el ticket: a partir de aquí cuenta como gasto del mes. De paso el
     * backend repasa la lista de la compra y marca lo que ha aparecido.
     */
    func confirm() async -> Bool {
        guard let id = receipt?.id else { return false }
        busyMessage = "Añadiendo a los gastos…"
        defer { busyMessage = nil }
        do {
            let result = try await ReceiptService.confirm(id: id)
            receipt = result.receipt
            shoppingCheck = result.shoppingCheck
            return true
        } catch {
            report(error)
            return false
        }
    }

    func discard() async {
        guard let id = receipt?.id else { return }
        busyMessage = "Descartando…"
        try? await ReceiptService.delete(id: id)
        receipt = nil
        busyMessage = nil
    }

    private func run(_ message: String, _ action: () async throws -> Receipt?) async {
        busyMessage = message
        errorMessage = nil
        do {
            if let updated = try await action() { receipt = updated }
        } catch {
            report(error)
        }
        busyMessage = nil
    }

    private func report(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/// Escáner de facturas de la compra.
///
/// El ticket se monta a base de fotos con la cámara de documentos del sistema:
/// cada una pasa por Vision y su texto se manda al backend, que va acumulando
/// las líneas. Al confirmar, el total entra como gasto del mes.
struct ReceiptScannerView: View {

    var receiptId: Int64?
    var manual = false
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var vm = ReceiptScannerViewModel()
    @State private var showScanner = false
    @State private var newItemDescription = ""
    @State private var newItemAmount = ""
    @State private var merchant = ""
    @State private var totalText = ""

    private var scannerAvailable: Bool { VNDocumentCameraViewController.isSupported }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if let check = vm.shoppingCheck, let receipt = vm.receipt {
                        // Ya confirmado: se enseña el repaso de la lista, que es
                        // la razón de ser del escaneo.
                        confirmationSummary(receipt: receipt, check: check)
                    } else if let receipt = vm.receipt {
                        summary(receipt)
                        if !manual { photos(receipt) }
                        items(receipt)
                        details(receipt)
                        closing(receipt)
                    } else {
                        ProgressView()
                            .tint(Theme.primaryLight)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .finanzBackground()
            .navigationTitle(manual ? "Compra a mano" : "Escanear factura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .task {
            await vm.start(receiptId: receiptId, manual: manual)
            sync()
        }
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptDocumentScanner(
                onFinish: { texts in
                    showScanner = false
                    Task {
                        await vm.addPages(texts)
                        sync()
                    }
                },
                onError: { message in
                    showScanner = false
                    vm.errorMessage = message
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Bloques

    /// Lo que se ve al cerrar el ticket: el gasto apuntado y el repaso de la
    /// lista. Lo que apareció en el ticket ya queda marcado como conseguido.
    private func confirmationSummary(receipt: Receipt, check: ShoppingCheck) -> some View {
        let accent: Color = (!check.listHadItems || check.complete) ? Theme.success : Theme.warning

        return VStack(alignment: .leading, spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gasto apuntado")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                    Text(receipt.total.currencyString)
                        .font(.display(30))
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }

            Card(borderColor: accent.opacity(0.35)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(check.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                    Text(check.message)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textBody)
                        .fixedSize(horizontal: false, vertical: true)

                    if check.listHadItems {
                        ProgressBar(value: Double(check.coveragePct) / 100.0, color: accent)
                        Text("\(check.foundCount) de \(check.totalPending) artículos")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }

                    if !check.missing.isEmpty {
                        SectionLabel(text: "Se te ha quedado")
                        ForEach(check.missing, id: \.self) { name in
                            Text("· \(name)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.warning)
                        }
                    }

                    if !check.found.isEmpty {
                        SectionLabel(text: "Marcado como conseguido")
                        ForEach(check.found, id: \.self) { name in
                            Text("✓ \(name)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }

            PrimaryButton(title: "Listo") {
                onFinished()
                dismiss()
            }
        }
    }

    private func summary(_ receipt: Receipt) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total del ticket")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                Text(receipt.total.currencyString)
                    .font(.display(32))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(receipt.pages.count) foto(s) · \(receipt.items.count) artículos leídos")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)

                if receipt.difference != 0 && !receipt.items.isEmpty {
                    Text("""
                         Faltan \(receipt.difference.magnitude.currencyString) entre las líneas \
                         leídas y el total impreso. Manda el total; revisa las líneas solo si \
                         quieres el detalle.
                         """)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.warning)
                        .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func photos(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PrimaryButton(title: receipt.pages.isEmpty ? "📷 Escanear el ticket"
                                                       : "📷 Añadir más fotos",
                          isLoading: vm.busyMessage == "Leyendo las fotos…",
                          isEnabled: scannerAvailable && vm.busyMessage == nil) {
                showScanner = true
            }

            Text(scannerAvailable
                 ? "La cámara deja disparar foto tras foto: cubre el ticket entero y al terminar se leen todas de golpe."
                 : "Este dispositivo no tiene cámara de documentos. Puedes apuntar las líneas a mano.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textFaint)

            if !receipt.pages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(receipt.pages) { page in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 12))
                                Text("Foto \(page.pageIndex + 1) · \(page.itemCount)")
                                    .font(.system(size: 12))
                                Button {
                                    Task { await vm.removePage(page.pageIndex) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private func items(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Artículos (\(receipt.items.count))")

            if receipt.items.isEmpty {
                Text(manual ? "Añade lo que has comprado."
                            : "Todavía no hay líneas. Escanea el ticket o añádelas a mano.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(receipt.items) { item in
                Card(padding: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textBody)
                                .lineLimit(1)
                            if item.quantity != 1, let unitPrice = item.unitPrice {
                                Text("\(item.quantity) × \(unitPrice.currencyString)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                            }
                        }
                        Spacer(minLength: 4)
                        Text(item.amount.currencyString)
                            .font(.display(14, weight: .semibold))
                            .foregroundStyle(Theme.primaryLight)
                        if let itemId = item.id {
                            Button {
                                Task { await vm.deleteItem(itemId: itemId) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Producto", text: $newItemDescription)
                    .textFieldStyle(DarkTextFieldStyle())
                TextField("0,00", text: $newItemAmount)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                Button {
                    guard let amount = Decimal.parse(newItemAmount),
                          !newItemDescription.trimmed.isEmpty else { return }
                    let description = newItemDescription.trimmed
                    newItemDescription = ""
                    newItemAmount = ""
                    Task { await vm.addItem(description: description, amount: amount) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryLight)
                        .frame(width: 44, height: 44)
                        .background(Theme.primary.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func details(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Datos de la compra")

            FieldLabel(text: "Comercio")
            TextField("Ej: Mercadona, frutería del barrio", text: $merchant)
                .textFieldStyle(DarkTextFieldStyle())
                .onSubmit {
                    guard merchant.trimmed != (receipt.merchant ?? "").trimmed else { return }
                    Task { await vm.updateDetails(ReceiptRequest(merchant: merchant.trimmed)) }
                }

            FieldLabel(text: "Fecha")
            DatePicker("", selection: Binding(
                get: { receipt.date },
                set: { newDate in Task { await vm.updateDetails(ReceiptRequest(date: newDate)) } }
            ), displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(Theme.primaryLight)

            FieldLabel(text: "Categoría")
            Picker("Categoría", selection: Binding(
                get: { receipt.category },
                set: { newCategory in
                    Task { await vm.updateDetails(ReceiptRequest(category: newCategory)) }
                }
            )) {
                ForEach(ExpenseCategory.all) { category in
                    Text(category.name).tag(category.name)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.primaryLight)

            FieldLabel(text: "Total (solo si el OCR no lo ha cogido bien)")
            HStack(spacing: 8) {
                TextField("0,00", text: $totalText)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.decimalPad)
                Button("Fijar") {
                    guard let value = Decimal.parse(totalText) else { return }
                    Task { await vm.updateDetails(ReceiptRequest(total: value)) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryLight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.primary.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func closing(_ receipt: Receipt) -> some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Añadir a los gastos de \(monthName(of: receipt.date))",
                          isLoading: vm.busyMessage == "Añadiendo a los gastos…",
                          isEnabled: vm.busyMessage == nil && receipt.total > 0) {
                // Al confirmar no se cierra: la vista pasa a enseñar el repaso
                // de la lista de la compra.
                Task { _ = await vm.confirm() }
            }

            Button("Descartar el ticket", role: .destructive) {
                Task {
                    await vm.discard()
                    onFinished()
                    dismiss()
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.danger)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // MARK: - Utilidades

    /// Copia a los campos editables lo que ha devuelto el backend.
    private func sync() {
        guard let receipt = vm.receipt else { return }
        merchant = receipt.merchant ?? ""
        totalText = "\(receipt.total)"
    }

    private func monthName(of date: Date) -> String {
        let index = Calendar.current.component(.month, from: date) - 1
        return Formatters.monthNames[max(0, min(11, index))].lowercased()
    }
}
