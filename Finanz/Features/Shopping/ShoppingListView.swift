import SwiftUI
import Observation

@MainActor
@Observable
final class ShoppingListViewModel {

    private(set) var items: [ShoppingItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// Lo que llevamos gastado en compra este mes, según los tickets.
    private(set) var receiptSummary = ReceiptSummary.empty
    /// Tickets a medio escanear, para poder retomarlos.
    private(set) var receiptDrafts: [Receipt] = []

    var pending: [ShoppingItem] { items.filter { !$0.purchased } }
    var purchased: [ShoppingItem] { items.filter(\.purchased) }

    var estimatedTotal: Decimal { items.reduce(0) { $0 + ($1.price ?? 0) } }
    var purchasedTotal: Decimal { purchased.reduce(0) { $0 + ($1.price ?? 0) } }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await ShoppingListService.all()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
        await loadReceipts()
    }

    /// Un fallo aquí no bloquea la lista de la compra, que es lo importante de
    /// esta pantalla, así que se ignora en silencio.
    func loadReceipts() async {
        let now = Date()
        receiptSummary = (try? await ReceiptService.summary(month: now.monthComponent,
                                                            year: now.yearComponent)) ?? .empty
        receiptDrafts = (try? await ReceiptService.drafts()) ?? []
    }

    func upsert(_ item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
    }

    /// Escucha los cambios mientras la pantalla esté abierta: lo que hagas
    /// desde otro dispositivo, o al escanear un ticket, aparece aquí solo.
    func observeChanges() async {
        for await event in ShoppingListStream.events() {
            if event.type == "DELETED" {
                items.removeAll { $0.id == event.itemId }
            } else if let item = event.item {
                upsert(item)
            }
        }
    }

    func toggle(_ item: ShoppingItem) async {
        do {
            let updated = try await ShoppingListService.togglePurchased(id: item.id)
            upsert(updated)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ item: ShoppingItem) async {
        let snapshot = items
        items.removeAll { $0.id == item.id }
        do {
            try await ShoppingListService.delete(id: item.id)
        } catch {
            items = snapshot
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Puerto de `ShoppingListPage.jsx`.
struct ShoppingListView: View {

    @State private var vm = ShoppingListViewModel()
    @State private var showForm = false
    @State private var editingItem: ShoppingItem?

    /// Ticket abierto en el escáner: `nil` = escáner cerrado.
    @State private var scannerTarget: ScannerTarget?

    /// Qué abre el escáner: un ticket nuevo, uno a medias o una compra a mano.
    private struct ScannerTarget: Identifiable {
        let id = UUID()
        var receiptId: Int64?
        var manual = false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    totals

                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await vm.load() }
                        }
                    }

                    receipts

                    section(title: "Pendientes (\(vm.pending.count))",
                            items: vm.pending,
                            emptyText: "Todo conseguido 🎉")

                    if !vm.purchased.isEmpty {
                        section(title: "Conseguidos (\(vm.purchased.count))",
                                items: vm.purchased,
                                emptyText: nil)
                    }

                    Button {
                        editingItem = nil
                        showForm = true
                    } label: {
                        Text("+ Añadir artículo")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Theme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .finanzBackground()
            .navigationTitle("Lista de la compra")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        // Se corta sola al cerrar la pantalla, que es cuando SwiftUI cancela
        // la tarea del `.task`.
        .task { await vm.observeChanges() }
        .sheet(isPresented: $showForm) {
            ShoppingItemFormView(item: editingItem,
                                 onSaved: { vm.upsert($0) },
                                 onDeleted: { item in Task { await vm.delete(item) } })
        }
        .sheet(item: $scannerTarget) { target in
            ReceiptScannerView(receiptId: target.receiptId,
                               manual: target.manual,
                               onFinished: { Task { await vm.loadReceipts() } })
        }
    }

    /// Facturas de la compra: gasto del mes, escáner y tickets sin terminar.
    private var receipts: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gastado en compra este mes")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                    Text(vm.receiptSummary.confirmedTotal.currencyString)
                        .font(.display(24))
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("\(vm.receiptSummary.confirmedCount) ticket(s) · media \(vm.receiptSummary.averageTicket.currencyString)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }

                PrimaryButton(title: "📷 Escanear factura") {
                    scannerTarget = ScannerTarget(receiptId: nil)
                }

                Button {
                    scannerTarget = ScannerTarget(receiptId: nil, manual: true)
                } label: {
                    Text("Apuntar compra a mano")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Theme.primaryLight)
                        .background(Theme.primary.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(vm.receiptDrafts) { draft in
                    Button {
                        scannerTarget = ScannerTarget(receiptId: draft.id)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.merchant ?? "Ticket sin terminar")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textBody)
                                    .lineLimit(1)
                                Text("\(draft.pages.count) foto(s) · \(draft.items.count) artículos")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            Spacer(minLength: 4)
                            Text(draft.total.currencyString)
                                .font(.display(13, weight: .semibold))
                                .foregroundStyle(Theme.warning)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var totals: some View {
        HStack(spacing: 12) {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total estimado")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                    Text(vm.estimatedTotal.currencyString)
                        .font(.display(20))
                        .foregroundStyle(Theme.textBody)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ya conseguido")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                    Text(vm.purchasedTotal.currencyString)
                        .font(.display(20))
                        .foregroundStyle(Theme.success)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, items: [ShoppingItem], emptyText: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)

            if items.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(items) { item in
                row(item)
            }
        }
    }

    /// Segunda línea de la fila: la periodicidad y, en lo ya conseguido,
    /// cuándo vuelve. Nil si no hay nada que contar.
    private static func subtitle(for item: ShoppingItem) -> String? {
        guard let recurrence = Catalogs.restockLabel(item.recurrenceMonths) else { return nil }
        guard item.purchased, let days = item.daysUntilDue else { return recurrence }

        switch days {
        case 1:          return "\(recurrence) · vuelve mañana"
        case 0:          return "\(recurrence) · toca reponerlo"
        case let d where d > 1:  return "\(recurrence) · vuelve en \(d) días"
        default:         return "\(recurrence) · tocaba hace \(-days) días"
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Card(padding: 12) {
            HStack(spacing: 10) {
                Button {
                    Task { await vm.toggle(item) }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(item.purchased ? Color.clear : Theme.borderStrong, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(item.purchased ? Theme.success : Color.clear)
                            )
                        if item.purchased {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.background)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.purchased ? "Desmarcar \(item.name)" : "Marcar \(item.name) como conseguido")

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textBody)
                        .strikethrough(item.purchased)
                        .lineLimit(1)
                    if let subtitle = Self.subtitle(for: item) {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if let price = item.effectivePrice {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(price.currencyString)
                            .font(.display(14, weight: .semibold))
                            .foregroundStyle(item.purchased ? Theme.success : Theme.primaryLight)
                        // Solo se aclara que es el precio real cuando difiere
                        // del estimado: si no, es ruido.
                        if let paid = item.lastPaidPrice, let estimated = item.price,
                           paid != estimated {
                            Text("pagado · est. \(estimated.currencyString)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textFaint)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .opacity(item.purchased ? 0.6 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
            showForm = true
        }
        .contextMenu {
            Button("Editar") {
                editingItem = item
                showForm = true
            }
            Button("Eliminar", role: .destructive) {
                Task { await vm.delete(item) }
            }
        }
    }
}

/// Alta / edición de artículo de la lista.
struct ShoppingItemFormView: View {

    var item: ShoppingItem?
    var onSaved: (ShoppingItem) -> Void
    var onDeleted: (ShoppingItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var priceText = ""
    @State private var recurrenceMonths: Int?
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FieldLabel(text: "Nombre del producto")
                    TextField("Ej: Arroz", text: $name)
                        .textFieldStyle(DarkTextFieldStyle())

                    FieldLabel(text: "Precio estimado (€) — opcional")
                    TextField("0,00", text: $priceText)
                        .textFieldStyle(DarkTextFieldStyle())
                        .keyboardType(.decimalPad)
                    if let paid = item?.lastPaidPrice {
                        Text("La última vez costó \(paid.currencyString)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                    }

                    FieldLabel(text: "¿Cada cuánto lo compras?")
                    Text("Al marcarlo como conseguido, vuelve solo a la lista cuando toque.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                              spacing: 8) {
                        ForEach(Catalogs.restockOptions, id: \.label) { option in
                            SelectableChip(title: option.label,
                                           isSelected: recurrenceMonths == option.months,
                                           accent: Theme.primaryLight) {
                                recurrenceMonths = option.months
                            }
                        }
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    PrimaryButton(title: item == nil ? "Añadir a la lista" : "Guardar cambios",
                                  isLoading: isSaving,
                                  isEnabled: !name.trimmed.isEmpty) {
                        Task { await save() }
                    }

                    if let item {
                        Button("Eliminar artículo", role: .destructive) {
                            onDeleted(item)
                            dismiss()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .finanzBackground()
            .navigationTitle(item == nil ? "Nuevo artículo" : "Editar artículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .onAppear {
            guard let item else { return }
            name = item.name
            if let price = item.price { priceText = "\(price)" }
            recurrenceMonths = item.recurrenceMonths
        }
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        let request = ShoppingItemRequest(name: name.trimmed,
                                          price: Decimal.parse(priceText),
                                          recurrenceMonths: recurrenceMonths)
        do {
            let saved: ShoppingItem
            if let item {
                saved = try await ShoppingListService.update(id: item.id, request)
            } else {
                saved = try await ShoppingListService.create(request)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
