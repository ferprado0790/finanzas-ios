import Foundation

// MARK: - Divisor de cuenta

/// `ParticipantDto` — alguien que estuvo en la comida.
///
/// No tiene relación con `User` a propósito: la gracia es repartir con quien
/// sea sin obligarle a registrarse en la app.
struct BillParticipant: Decodable, Identifiable, Hashable {
    let id: Int64
    let name: String
    /// Quien creó la cuenta: su parte es la que se apunta como gasto.
    let owner: Bool
    let settled: Bool
    /// Lo consumido por esta persona.
    let items: Decimal
    /// Su parte de la propina o el servicio.
    let extra: Decimal
    /// Lo que le toca pagar en total.
    let total: Decimal
}

/// `BillItemDto`
struct BillItem: Decodable, Identifiable, Hashable {
    let id: Int64
    let description: String
    let amount: Decimal
    let assigneeIds: [Int64]
    /// Sin asignar: cuenta como compartida entre todos.
    let sharedByAll: Bool
}

/// `BillSplitDto`
struct BillSplit: Decodable, Identifiable, Hashable {
    let id: Int64
    let place: String?
    let date: Date
    let total: Decimal
    let totalOverridden: Bool
    let status: String              // OPEN | SETTLED
    let expenseId: Int64?
    let notes: String?
    let participants: [BillParticipant]
    let items: [BillItem]
    let itemsTotal: Decimal
    /// Propina, servicio o redondeo: lo que el total tiene de más.
    let extra: Decimal
    /// Lo que te toca pagar a ti.
    let yourShare: Decimal
    /// Lo que te deben los demás.
    let owedToYou: Decimal
}

/// `BillSplitRequest` — todo opcional: la cuenta se va rellenando.
struct BillSplitRequest: Encodable {
    var place: String?
    var date: Date?
    var total: Decimal?
    var notes: String?
}

/// `ParticipantRequest`
struct ParticipantRequest: Encodable {
    let name: String
}

/// `BillItemRequest`
struct BillItemRequest: Encodable {
    let description: String
    let amount: Decimal
    /// Quiénes la comparten. Vacío = de todos.
    var assigneeIds: [Int64] = []
}

/// `BillOcrRequest` — texto que ha reconocido Vision en la foto de la cuenta.
struct BillOcrRequest: Encodable {
    let rawText: String
}
