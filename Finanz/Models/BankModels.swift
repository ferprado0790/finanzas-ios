import Foundation

// MARK: - Bancos disponibles

/// `BankDtos.InstitutionDto`
struct BankInstitution: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bic: String?
    let logo: String?
}

// MARK: - Vinculación

/// `BankDtos.BankAccountDto`
struct BankAccount: Codable, Identifiable, Hashable {
    let id: Int64
    let maskedIban: String
    let name: String?
    let ownerName: String?
    let currency: String
    let syncEnabled: Bool
    let lastSyncAt: Date?
}

/// `BankDtos.BankConnectionDto`
struct BankConnection: Codable, Identifiable, Hashable {
    let id: Int64
    let institutionId: String
    let institutionName: String
    let institutionLogo: String?
    let status: String
    let autoConfirm: Bool
    let consentExpiresAt: Date?
    let daysUntilExpiry: Int?
    let needsRenewal: Bool
    let lastSyncAt: Date?
    let lastSyncError: String?
    let accounts: [BankAccount]

    var isLinked: Bool { status == "LINKED" }

    /// Texto de estado para la tarjeta, ya resuelto: la vista solo lo pinta.
    var statusText: String {
        if needsRenewal { return "Permiso caducado" }
        switch status {
        case "LINKED":   return "Conectado"
        case "PENDING":  return "Sin terminar"
        case "EXPIRED":  return "Permiso caducado"
        case "REJECTED": return "Autorización cancelada"
        default:         return "Con problemas"
        }
    }

    /// Avisa cuando quedan dos semanas o menos. El permiso dura 90 días por
    /// obligación de la PSD2 y, cuando vence, los movimientos dejan de llegar
    /// sin que nada lo indique: hay que decirlo antes, no después.
    var expiryWarning: String? {
        guard isLinked, let days = daysUntilExpiry else { return nil }
        if days <= 0 { return "El permiso ha caducado. Vuelve a autorizarlo para seguir recibiendo los gastos." }
        if days <= 14 {
            return days == 1
                ? "El permiso caduca mañana. Renuévalo para no perder los gastos."
                : "El permiso caduca en \(days) días. Renuévalo cuando puedas."
        }
        return nil
    }
}

/// `BankDtos.BankStatusDto`
struct BankStatus: Codable {
    let available: Bool
    let connections: [BankConnection]
    let pendingMovements: Int

    static let unavailable = BankStatus(available: false, connections: [], pendingMovements: 0)
}

/// `BankDtos.LinkBankResponse`
struct BankLinkStart: Codable {
    let connectionId: Int64
    let reference: String
    let authUrl: String
}

/// `BankDtos.SyncResultDto`
struct BankSyncResult: Codable {
    let created: Int
    let promoted: Int
    let autoConfirmed: Int
    let discarded: Int
    let rateLimited: Bool
    let error: String?
    let syncedAt: Date?

    /// Lo que se le enseña al usuario tras sincronizar a mano.
    var summary: String {
        if rateLimited {
            return "El banco no admite más consultas por hoy. Se reintentará solo."
        }
        if let error, !error.isEmpty { return error }
        if created == 0 && autoConfirmed == 0 { return "Sin novedades." }
        if autoConfirmed > 0 && created == autoConfirmed {
            return created == 1 ? "1 gasto apuntado." : "\(created) gastos apuntados."
        }
        return created == 1 ? "1 movimiento nuevo." : "\(created) movimientos nuevos."
    }
}

// MARK: - Movimientos

/// `BankDtos.CardMovementDto`
struct CardMovement: Codable, Identifiable, Hashable {
    let id: Int64
    let bookingDate: Date
    let amount: Decimal
    let currency: String
    let merchant: String
    let rawDescription: String?
    let kind: String
    let kindLabel: String
    let suggestedCategory: String?
    let status: String
    let pendingAtBank: Bool
    let expenseId: Int64?
    let accountLabel: String?

    var category: String { suggestedCategory ?? "Otro" }

    /// Icono SF Symbol según el tipo de movimiento.
    var symbol: String {
        switch kind {
        case "CARD":         return "creditcard.fill"
        case "BIZUM":        return "iphone.gen3"
        case "DIRECT_DEBIT": return "arrow.clockwise.circle.fill"
        case "TRANSFER":     return "arrow.left.arrow.right"
        case "ATM":          return "banknote.fill"
        case "FEE":          return "percent"
        default:             return "questionmark.circle.fill"
        }
    }

    /// Una retirada de efectivo no es un gasto en sí: el gasto viene después,
    /// en efectivo, y apuntar las dos cosas lo contaría dos veces.
    var isCashWithdrawal: Bool { kind == "ATM" }
}

/// `BankDtos.ConfirmMovementRequest`
struct ConfirmMovementRequest: Encodable {
    let category: String?
    let description: String?
    let notes: String?
}

/// `BankDtos.BulkConfirmRequest`
struct BulkConfirmRequest: Encodable {
    let ids: [Int64]
}

/// `BankDtos.AutoConfirmRequest`
struct AutoConfirmRequest: Encodable {
    let autoConfirm: Bool
}
