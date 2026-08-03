import SwiftUI

/// Navegación principal. La web usa una barra inferior de 6 elementos; en iOS
/// mantenemos 5 pestañas (convención del sistema) y Análisis e Informes se
/// abren desde el Inicio, que es donde la web ya los enlazaba.
struct MainTabView: View {

    enum Tab: Hashable {
        case dashboard, incomes, expenses, shopping, budget
    }

    @State private var selection: Tab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Inicio", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.dashboard)

            IncomeView()
                .tabItem { Label("Ingresos", systemImage: "arrow.up.circle.fill") }
                .tag(Tab.incomes)

            ExpenseView()
                .tabItem { Label("Gastos", systemImage: "arrow.down.circle.fill") }
                .tag(Tab.expenses)

            ShoppingListView()
                .tabItem { Label("Compras", systemImage: "checklist") }
                .tag(Tab.shopping)

            BudgetCheckView()
                .tabItem { Label("Aprobar", systemImage: "sparkles") }
                .tag(Tab.budget)
        }
        .toolbarBackground(Theme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
