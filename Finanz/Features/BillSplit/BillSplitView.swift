import SwiftUI
import Observation
import VisionKit

@MainActor
@Observable
final class BillSplitViewModel {

    private(set) var bill: BillSplit?
    /// Texto del paso en curso ("Leyendo la cuenta…"), o nil.
    private(set) var busyMessage: String?
    private(set) var confirmed = false
    var errorMessage: String?

    func start(billId: Int64?) async {
        guard bill == nil else { return }
        busyMessage = "Preparando la cuenta…"
        do {
            if let billId {
                bill = try await BillSplitService.get(id: billId)
            } else {
                bill = try await BillSplitService.create(BillSplitRequest(date: Date()))
            }
        } catch {
            report(error)
        }
        busyMessage = nil
    }

    func readPhotos(_ texts: [String]) async {
        guard let id = bill?.id else { return }
        await run("Leyendo la cuenta…") {
            var latest: BillSplit?
            for text in texts {
                latest = try await BillSplitService.readPhoto(id: id, rawText: text)
            }
            return latest
        }
    }

    func addParticipant(_ name: String) async {
        guard let id = bill?.id else { return }
        await run("Añadiendo…") { try await BillSplitService.addParticipant(id: id, name: name) }
    }

    func removeParticipant(_ participantId: Int64) async {
        guard let id = bill?.id else { return }
        await run("Quitando…") {
            try await BillSplitService.removeParticipant(id: id, participantId: participantId)
        }
    }

    func toggleSettled(_ participantId: Int64) async {
        guard let id = bill?.id else { return }
        await run("Guardando…") {
            try await BillSplitService.toggleSettled(id: id, participantId: participantId)
        }
    }

    func addItem(description: String, amount: Decimal) async {
        guard let id = bill?.id else { return }
        await run("Guardando…") {
            try await BillSplitService.addItem(
                id: id, BillItemRequest(description: description, amount: amount))
        }
    }

    /// Marca o desmarca a alguien en una línea: es el check del reparto.
    func toggleAssignee(item: BillItem, participantId: Int64) async {
        guard let id = bill?.id else { return }
        let next = item.assigneeIds.contains(participantId)
            ? item.assigneeIds.filter { $0 != participantId }
            : item.assigneeIds + [participantId]

        await run("Guardando…") {
            try await BillSplitService.updateItem(
                id: id, itemId: item.id,
                BillItemRequest(description: item.description, amount: item.amount,
                                assigneeIds: next))
        }
    }

    func deleteItem(_ itemId: Int64) async {
        guard let id = bill?.id else { return }
        await run("Borrando…") { try await BillSplitService.deleteItem(id: id, itemId: itemId) }
    }

    func updateDetails(_ request: BillSplitRequest) async {
        guard let id = bill?.id else { return }
        await run("Guardando…") { try await BillSplitService.update(id: id, request) }
    }

    /// Apunta tu parte como gasto. Lo de los demás no sale de tu bolsillo.
    func confirm() async {
        guard let id = bill?.id else { return }
        busyMessage = "Apuntando tu parte…"
        defer { busyMessage = nil }
        do {
            bill = try await BillSplitService.confirm(id: id)
            confirmed = true
        } catch {
            report(error)
        }
    }

    func discard() async {
        guard let id = bill?.id else { return }
        busyMessage = "Descartando…"
        try? await BillSplitService.delete(id: id)
        bill = nil
        busyMessage = nil
    }

    private func run(_ message: String, _ action: () async throws -> BillSplit?) async {
        busyMessage = message
        errorMessage = nil
        do {
            if let updated = try await action() { bill = updated }
        } catch {
            report(error)
        }
        busyMessage = nil
    }

    private func report(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/**
 Divisor de cuenta del restaurante.

 Se hace una foto de la cuenta, se apunta quién estaba —sin que tengan que tener
 la app— y se marca con un check qué es de cada uno. Al cerrar, solo tu parte se
 apunta como gasto.
 */
struct BillSplitView: View {

    var billId: Int64?
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var vm = BillSplitViewModel()
    @State private var showScanner = false
    @State private var newParticipant = ""
    @State private var newItemDescription = ""
    @State private var newItemAmount = ""
    @State private var place = ""
    @State private var totalText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if let bill = vm.bill {
                        summary(bill)
                        scanButton(bill)
                        participants(bill)
                        items(bill)
                        details(bill)
                        closing(bill)
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
            .navigationTitle("Dividir la cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .task {
            await vm.start(billId: billId)
            sync()
        }
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptDocumentScanner(
                onFinish: { texts in
                    showScanner = false
                    Task {
                        await vm.readPhotos(texts)
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

    private func summary(_ bill: BillSplit) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tu parte")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                Text(bill.yourShare.currencyString)
                    .font(.display(32))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("de \(bill.total.currencyString) entre \(bill.participants.count) personas")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)

                if bill.owedToYou > 0 {
                    Text("Te deben \(bill.owedToYou.currencyString)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.warning)
                        .padding(.top, 2)
                }
                if bill.extra > 0 {
                    Text("""
                         Incluye \(bill.extra.currencyString) de propina o servicio, repartida \
                         según lo que ha consumido cada uno.
                         """)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func scanButton(_ bill: BillSplit) -> some View {
        PrimaryButton(title: bill.items.isEmpty ? "📷 Hacer foto de la cuenta"
                                                : "📷 Añadir otra foto",
                      isLoading: vm.busyMessage == "Leyendo la cuenta…",
                      isEnabled: VNDocumentCameraViewController.isSupported
                                 && vm.busyMessage == nil) {
            showScanner = true
        }
    }

    private func participants(_ bill: BillSplit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Quién estaba (\(bill.participants.count))")
            Text("No hace falta que tengan la app: basta con el nombre.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)

            ForEach(bill.participants) { person in
                Card(padding: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.owner ? "\(person.name) (tú)" : person.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textBody)
                                .lineLimit(1)
                            if person.extra > 0 {
                                Text("\(person.items.currencyString) + \(person.extra.currencyString) propina")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textFaint)
                            }
                        }
                        Spacer(minLength: 4)
                        Text(person.total.currencyString)
                            .font(.display(14, weight: .semibold))
                            .foregroundStyle(Theme.primaryLight)

                        if !person.owner {
                            // "Ya me ha pagado": lo que quede sin marcar es lo
                            // que te deben.
                            Button(person.settled ? "Pagado" : "Debe") {
                                Task { await vm.toggleSettled(person.id) }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(person.settled ? Theme.success : Theme.warning)
                            .buttonStyle(.plain)

                            Button {
                                Task { await vm.removeParticipant(person.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Nombre", text: $newParticipant)
                    .textFieldStyle(DarkTextFieldStyle())
                Button("Añadir") {
                    let name = newParticipant.trimmed
                    guard !name.isEmpty else { return }
                    newParticipant = ""
                    Task { await vm.addParticipant(name) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryLight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.primary.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .buttonStyle(.plain)
            }
        }
    }

    private func items(_ bill: BillSplit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Qué se pidió (\(bill.items.count))")

            if bill.items.isEmpty {
                Text("Haz una foto de la cuenta o añade las líneas a mano.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(bill.items) { item in
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(item.description)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textBody)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.amount.currencyString)
                                .font(.display(14, weight: .semibold))
                                .foregroundStyle(Theme.primaryLight)
                            Button {
                                Task { await vm.deleteItem(item.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textFaint)
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(bill.participants) { person in
                                    SelectableChip(
                                        title: person.name,
                                        isSelected: item.assigneeIds.contains(person.id),
                                        accent: Theme.success
                                    ) {
                                        Task { await vm.toggleAssignee(item: item,
                                                                       participantId: person.id) }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        if item.sharedByAll {
                            Text("Sin marcar a nadie: se reparte entre todos.")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Plato", text: $newItemDescription)
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

    private func details(_ bill: BillSplit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Datos de la cuenta")

            FieldLabel(text: "Sitio")
            TextField("Ej: Casa Paco", text: $place)
                .textFieldStyle(DarkTextFieldStyle())
                .onSubmit {
                    guard place.trimmed != (bill.place ?? "").trimmed else { return }
                    Task { await vm.updateDetails(BillSplitRequest(place: place.trimmed)) }
                }

            FieldLabel(text: "Fecha")
            DatePicker("", selection: Binding(
                get: { bill.date },
                set: { newDate in
                    Task { await vm.updateDetails(BillSplitRequest(date: newDate)) }
                }
            ), displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(Theme.primaryLight)

            FieldLabel(text: "Total de la cuenta (con propina)")
            HStack(spacing: 8) {
                TextField("0,00", text: $totalText)
                    .textFieldStyle(DarkTextFieldStyle())
                    .keyboardType(.decimalPad)
                Button("Fijar") {
                    guard let value = Decimal.parse(totalText) else { return }
                    Task { await vm.updateDetails(BillSplitRequest(total: value)) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryLight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.primary.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .buttonStyle(.plain)
            }
        }
    }

    private func closing(_ bill: BillSplit) -> some View {
        VStack(spacing: 12) {
            if vm.confirmed {
                Text("✓ Tu parte (\(bill.yourShare.currencyString)) ya está en tus gastos.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.success)
                PrimaryButton(title: "Listo") {
                    onFinished()
                    dismiss()
                }
            } else {
                PrimaryButton(title: "Apuntar mi parte (\(bill.yourShare.currencyString))",
                              gradient: Theme.dangerGradient,
                              isLoading: vm.busyMessage == "Apuntando tu parte…",
                              isEnabled: vm.busyMessage == nil && bill.yourShare > 0) {
                    Task { await vm.confirm() }
                }
            }

            Button("Descartar la cuenta", role: .destructive) {
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

    /// Copia a los campos editables lo que ha devuelto el backend.
    private func sync() {
        guard let bill = vm.bill else { return }
        place = bill.place ?? ""
        totalText = "\(bill.total)"
    }
}
