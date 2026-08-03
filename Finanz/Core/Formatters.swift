import Foundation

enum Formatters {

    /// "1.234,56 €" — mismo formato que `toLocaleString("es-ES", { currency: "EUR" })`.
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = AppConfig.locale
        f.currencyCode = AppConfig.currencyCode
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppConfig.locale
        f.dateFormat = "dd MMM"
        return f
    }()

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppConfig.locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let monthNames = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                             "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    static let monthNamesShort = ["Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
}

extension Decimal {
    /// Importe formateado como moneda.
    var currencyString: String {
        Formatters.currency.string(from: self as NSDecimalNumber) ?? "0,00 €"
    }

    /// Con signo explícito, para listas de movimientos.
    func signedCurrencyString(positive: Bool) -> String {
        (positive ? "+" : "-") + magnitude.currencyString
    }

    var doubleValue: Double {
        (self as NSDecimalNumber).doubleValue
    }

    var magnitude: Decimal {
        self < 0 ? -self : self
    }

    /// Convierte lo que escribe la persona ("12,50", "12.50", "12,50 €") en `Decimal`.
    static func parse(_ text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension Double {
    var decimalValue: Decimal {
        Decimal(self)
    }
}

extension Date {
    var monthComponent: Int { Calendar.current.component(.month, from: self) }
    var yearComponent: Int { Calendar.current.component(.year, from: self) }
}
