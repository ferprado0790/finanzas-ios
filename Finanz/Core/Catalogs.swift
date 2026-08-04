import SwiftUI

/// Categoría de gasto: mismas 12 que en `ExpensePage.jsx`, con su icono y color.
struct ExpenseCategory: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let symbol: String      // SF Symbol
    let emoji: String
    let color: Color

    static let all: [ExpenseCategory] = [
        .init(name: "Vivienda",      symbol: "house.fill",              emoji: "🏠", color: Color(hex: 0x6C63FF)),
        .init(name: "Alimentación",  symbol: "cart.fill",               emoji: "🛒", color: Color(hex: 0xFFB347)),
        .init(name: "Transporte",    symbol: "car.fill",                emoji: "🚗", color: Color(hex: 0x4FC3F7)),
        .init(name: "Salud",         symbol: "cross.case.fill",         emoji: "💊", color: Color(hex: 0x6DFFC0)),
        .init(name: "Ocio",          symbol: "gamecontroller.fill",     emoji: "🎮", color: Color(hex: 0xFF5A7A)),
        .init(name: "Ropa",          symbol: "tshirt.fill",             emoji: "👕", color: Color(hex: 0xCE93D8)),
        .init(name: "Educación",     symbol: "book.fill",               emoji: "📚", color: Color(hex: 0xFFF176)),
        .init(name: "Tecnología",    symbol: "laptopcomputer",          emoji: "💻", color: Color(hex: 0x80CBC4)),
        .init(name: "Restaurantes",  symbol: "fork.knife",              emoji: "🍽️", color: Color(hex: 0xFFAB91)),
        .init(name: "Suscripciones", symbol: "arrow.triangle.2.circlepath", emoji: "📱", color: Color(hex: 0xB39DDB)),
        .init(name: "Ahorro",        symbol: "banknote.fill",           emoji: "🏦", color: Color(hex: 0xA5D6A7)),
        .init(name: "Otro",          symbol: "ellipsis.circle.fill",    emoji: "💰", color: Color(hex: 0x90A4AE))
    ]

    static func find(_ name: String) -> ExpenseCategory {
        all.first { $0.name == name } ?? all[all.count - 1]
    }

    /// Color estable para categorías que no están en el catálogo (vienen del backend).
    static func color(for name: String) -> Color {
        if let match = all.first(where: { $0.name == name }) { return match.color }
        let palette: [Color] = [Theme.primary, Theme.warning, Theme.info, Theme.success,
                                Theme.danger, Theme.primaryLight, Color(hex: 0x90A4AE)]
        // Suma de bytes en lugar de hashValue: estable entre lanzamientos.
        let seed = name.utf8.reduce(0) { $0 &+ Int($1) }
        return palette[seed % palette.count]
    }
}

enum Catalogs {
    /// Tipos de trabajo (IncomePage.jsx)
    static let jobTypes = ["Nómina", "Freelance", "Negocio", "Alquiler",
                           "Inversiones", "Pensión", "Beca", "Otro"]

    /// Frecuencias de gasto (ExpensePage.jsx)
    static let frequencies = ["Puntual", "Diario", "Semanal", "Mensual", "Anual"]

    /// Categorías del comprobador de presupuesto (BudgetCheckPage.jsx)
    static let budgetCategories = ["Alimentación", "Ocio", "Ropa", "Tecnología", "Viajes",
                                   "Salud", "Educación", "Restaurantes", "Otro"]

    /// Atajos del alta rápida de comida preparada. Son solo un punto de partida:
    /// los sitios que uses de verdad los ofrece el backend en `expenses/frequent`.
    static let foodPlaces = ["Restaurante", "Bar / cafetería", "Comida para llevar",
                             "Glovo", "Just Eat", "Uber Eats", "Deliveroo"]

    /// Categoría a la que va la comida preparada.
    static let foodCategory = "Restaurantes"
}
