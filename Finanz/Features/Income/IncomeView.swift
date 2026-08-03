import SwiftUI

/// Puerto de `IncomePage.jsx`: trabajos con barra de progreso sobre lo esperado
/// y entradas del mes seleccionado.
struct IncomeView: View {

    @State private var vm = IncomeViewModel()
    @State private var showJobForm = false
    @State private var showIncomeForm = false
    @State private var editingJob: Job?
    @State private var editingIncome: Income?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonthSelector(month: $vm.month, year: $vm.year)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.total.currencyString)
                            .font(.display(34))
                            .foregroundStyle(Theme.success)
                        Text("Total · \(vm.jobs.count) trabajo\(vm.jobs.count == 1 ? "" : "s")")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                    }

                    if let errorMessage = vm.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            Task { await vm.load() }
                        }
                    }

                    jobsSection
                    incomesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .finanzBackground()
            .navigationTitle("Mis ingresos")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task(id: "\(vm.month)-\(vm.year)") { await vm.load() }
        .sheet(isPresented: $showJobForm) {
            JobFormView(job: editingJob) { _ in
                Task { await vm.load() }
            }
        }
        .sheet(isPresented: $showIncomeForm) {
            IncomeFormView(income: editingIncome) { _ in
                Task { await vm.load() }
            }
        }
    }

    // MARK: - Trabajos

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Mis trabajos")

            if vm.jobs.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "briefcase",
                               title: "Aún no hay fuentes de ingreso",
                               subtitle: "Añade tu nómina, tus proyectos freelance o cualquier otra entrada.")
            }

            ForEach(vm.jobs) { job in
                jobCard(job)
            }

            Button {
                editingJob = nil
                showJobForm = true
            } label: {
                Text("+ Añadir trabajo")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Theme.primary)
                    .background(Theme.primary.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.primary.opacity(0.28), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func jobCard(_ job: Job) -> some View {
        let progress = vm.progress(for: job)

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textBody)
                        Text(job.type)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(progress.total.currencyString)
                            .font(.display(16))
                            .foregroundStyle(Theme.success)
                        Text("/ \((job.expectedMonthly ?? 0).currencyString)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                ProgressBar(value: progress.fraction,
                            color: progress.fraction >= 1 ? Theme.success : Theme.primary,
                            height: 4)

                HStack(spacing: 8) {
                    Button {
                        editingJob = job
                        showJobForm = true
                    } label: {
                        Text("Editar")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .foregroundStyle(Theme.textMuted)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.borderStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await vm.deleteJob(job) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(Theme.danger)
                            .background(Theme.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.danger.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar \(job.name)")
                }
            }
        }
    }

    // MARK: - Entradas del mes

    private var incomesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Entradas este mes")

            if vm.incomes.isEmpty && !vm.isLoading {
                EmptyStateView(icon: "tray", title: "Sin entradas registradas este mes")
            }

            ForEach(vm.incomes) { income in
                incomeRow(income)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingIncome = income
                        showIncomeForm = true
                    }
                    .contextMenu {
                        Button("Editar") {
                            editingIncome = income
                            showIncomeForm = true
                        }
                        Button("Eliminar", role: .destructive) {
                            Task { await vm.deleteIncome(income) }
                        }
                    }
            }

            Button {
                editingIncome = nil
                showIncomeForm = true
            } label: {
                Text("+ Registrar ingreso")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Theme.success)
                    .background(Theme.success.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.success.opacity(0.28), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func incomeRow(_ income: Income) -> some View {
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(income.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textBody)
                    HStack(spacing: 6) {
                        Text("\(income.jobName ?? "Sin trabajo") · \(Formatters.shortDate.string(from: income.date))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                        if income.recurring {
                            Text("recurrente")
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.primary.opacity(0.15))
                                .foregroundStyle(Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                Spacer(minLength: 4)
                Text("+\(income.amount.currencyString)")
                    .font(.display(16))
                    .foregroundStyle(Theme.success)
            }
        }
    }
}
