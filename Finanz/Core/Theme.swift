import SwiftUI

/// Paleta portada 1:1 desde `finanzas-app` (tema oscuro).
enum Theme {

    // Fondos
    static let background = Color(hex: 0x0A0A0F)
    static let surface = Color(hex: 0x12121A)
    static let surfaceAlt = Color(hex: 0x1A1A28)
    static let border = Color(hex: 0x1E1E2E)
    static let borderStrong = Color(hex: 0x2E2E44)

    // Texto
    static let textPrimary = Color.white
    static let textBody = Color(hex: 0xDDDDF0)
    static let textMuted = Color(hex: 0x6B6B8A)
    static let textFaint = Color(hex: 0x4A4A6A)

    // Acentos
    static let primary = Color(hex: 0x6C63FF)
    static let primaryLight = Color(hex: 0x9C5FFF)
    static let success = Color(hex: 0x6DFFC0)
    static let danger = Color(hex: 0xFF5A7A)
    static let warning = Color(hex: 0xFFB347)
    static let info = Color(hex: 0x4FC3F7)

    static let primaryGradient = LinearGradient(
        colors: [primary, primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [danger, Color(hex: 0xFF8E53)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Color del balance / tasa de ahorro según sea saludable o no.
    static func balanceColor(_ value: Decimal) -> Color {
        value >= 0 ? success : danger
    }

    static func savingsColor(_ rate: Int) -> Color {
        rate >= 20 ? success : warning
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    /// Cifras y titulares: la web usa Space Grotesk; aquí usamos la variante
    /// rounded del sistema, que da el mismo carácter sin empaquetar fuentes.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
