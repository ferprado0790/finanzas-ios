import SwiftUI

/// Puerto de `Dashboard.jsx`: saludo, balance del mes, tarjetas de ingresos y
/// gastos, accesos rápidos y movimientos recientes.
struct DashboardView: View {

    @Environment(SessionStore.self) private var session
    @State private var vm = DashboardViewModel()
    @State private var showIncomeForm = false
    @State private var showExpenseForm = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greeting
                    balanceCard
                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await vm.load() }
                        }
                    }
                    statsRow
                    quickActions
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .finanzBackground()
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Ajustes", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            session.signOut()
                        } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showIncomeForm) {
            IncomeFormView { _ in Task { await vm.load() } }
        }
        .sheet(isPresented: $showExpenseForm) {
            ExpenseFormView { _ in Task { await vm.load() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Secciones

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hola de nuevo,")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
            Text("\(session.user?.name ?? "Usuario") 👋")
                .font(.display(22))
                .foregroundStyle(Theme.textPrimary)
            Text("\(vm.monthTitle) · \(vm.summary.jobCount) fuente\(vm.summary.jobCount == 1 ? "" : "s") de ingreso")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceCard: some View {
        Card(padding: 24) {
            VStack(spacing: 8) {
                Text("BALANCE DEL MES")
                    .font(.system(size: 12))
                    .kerning(1)
                    .foregroundStyle(Theme.textMuted)

                if vm.isLoading && vm.summary.balance == 0 {
                    Text("···")
                        .font(.display(40))
                        .foregroundStyle(Theme.borderStrong)
                } else {
                    Text(vm.summary.balance.currencyString)
                        .font(.display(40))
                        .foregroundStyle(Theme.balanceColor(vm.summary.balance))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: vm.summary.savingsRate >= 20 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text("Tasa de ahorro: \(vm.summary.savingsRate)%")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.savingsColor(vm.summary.savingsRate))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.savingsColor(vm.summary.savingsRate).opacity(0.13))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(icon: "briefcase.fill",
                     label: "Ingresos",
                     value: vm.summary.totalIncome.currencyString,
                     color: Theme.success,
                     subtitle: "\(vm.summary.jobCount) trabajos")
            StatTile(icon: "cart.fill",
                     label: "Gastos",
                     value: vm.summary.totalExpenses.currencyString,
                     color: Theme.danger,
                     subtitle: nil)
        }
    }

    private var quickActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            QuickActionButton(icon: "arrow.up", title: "Añadir ingreso", color: Theme.primary) {
                showIncomeForm = true
            }
            QuickActionButton(icon: "arrow.down", title: "Añadir gasto", color: Theme.danger) {
                showExpenseForm = true
            }
            NavigationLink {
                AnalysisView()
            } label: {
                QuickActionLabel(icon: "chart.pie.fill", title: "Ver análisis", color: Theme.warning)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ReportView()
            } label: {
                QuickActionLabel(icon: "doc.text.fill", title: "Informes", color: Theme.success)
            }
            .buttonStyle(.plain)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Movimientos recientes")

            if vm.isLoading && vm.recentExpenses.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if vm.recentExpenses.isEmpty {
                EmptyStateView(icon: "tray", title: "Sin movimientos este mes")
            } else {
                ForEach(vm.recentExpenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }
        }
    }
}

// MARK: - Piezas del dashboard

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var subtitle: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.5)
                    .foregroundStyle(Theme.textMuted)
                Text(value)
                    .font(.display(20))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }
}

struct QuickActionLabel: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionLabel(icon: icon, title: title, color: color)
        }
        .buttonStyle(.plain)
    }
}
