import Foundation

// MARK: - Facturas de la compra

/// `ReceiptItemDto`
struct ReceiptItem: Codable, Identifiable, Hashable {
    let id: Int64?
    let pageIndex: Int
    let description: String
    let quantity: Decimal
    let unitPrice: Decimal?
    let amount: Decimal
    let manual: Bool
}

/// `ReceiptPageDto` — una foto del ticket.
struct ReceiptPage: Codable, Identifiable, Hashable {
    let id: Int64
    let pageIndex: Int
    let itemCount: Int
}

/// `ReceiptDto`
struct Receipt: Codable, Identifiable, Hashable {
    let id: Int64
    let merchant: String?
    let date: Date
    let total: Decimal
    let totalOverridden: Bool
    let category: String
    let source: String          // CAMERA | MANUAL
    let status: String          // DRAFT | CONFIRMED
    let expenseId: Int64?
    let notes: String?
    let pages: [ReceiptPage]
    let items: [ReceiptItem]
    let itemsTotal: Decimal
    /// Lo que se lleva el total impreso respecto a la suma de líneas leídas.
    let difference: Decimal

    var isDraft: Bool { status == "DRAFT" }
}

/// `ReceiptRequest` — todos los campos son opcionales: un ticket recién
/// empezado no sabe todavía ni el comercio ni el total.
struct ReceiptRequest: Encodable {
    var merchant: String?
    var date: Date?
    var total: Decimal?
    var category: String?
    var source: String?
    var notes: String?
}

/// `ReceiptPageRequest` — texto que ha reconocido Vision en una foto.
struct ReceiptPageRequest: Encodable {
    let rawText: String
    var pageIndex: Int?
}

/// `ReceiptItemRequest`
struct ReceiptItemRequest: Encodable {
    let description: String
    let amount: Decimal
    var quantity: Decimal?
    var unitPrice: Decimal?
}

/// `ShoppingCheckDto` — repaso de la lista de la compra al cerrar un ticket.
struct ShoppingCheck: Decodable, Hashable {
    let listHadItems: Bool
    let complete: Bool
    let totalPending: Int
    let foundCount: Int
    let coveragePct: Int
    let found: [String]
    let missing: [String]
    let title: String
    let message: String
}

/// `ReceiptConfirmationDto` — lo que devuelve confirmar una factura.
struct ReceiptConfirmation: Decodable {
    let receipt: Receipt
    let shoppingCheck: ShoppingCheck
}

/// `DeviceTokenRequest` — dispositivo donde recibir los avisos.
struct DeviceTokenRequest: Encodable {
    let token: String
    var platform: String = "IOS"
}

/// `ReceiptSummaryDto`
struct ReceiptSummary: Codable, Hashable {
    let month: Int
    let year: Int
    let confirmedTotal: Decimal
    let draftTotal: Decimal
    let confirmedCount: Int
    let draftCount: Int
    let averageTicket: Decimal

    static let empty = ReceiptSummary(month: 0, year: 0, confirmedTotal: 0, draftTotal: 0,
                                      confirmedCount: 0, draftCount: 0, averageTicket: 0)
}
