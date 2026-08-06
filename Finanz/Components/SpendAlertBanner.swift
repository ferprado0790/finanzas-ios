import SwiftUI
import Observation

/// Semáforo del gasto: si estaba previsto, si hay presupuesto y con qué cifras.
/// Informa, no impide guardar.
struct SpendAlertBanner: View {

    let alert: SpendAlert

    private var accent: Color {
        switch alert.level {
        case "WARNING": return Theme.danger
        case "CAUTION": return Theme.warning
        default:        return Theme.success
        }
    }

    private var symbol: String {
        switch alert.level {
        case "WARNING": return "exclamationmark.octagon.fill"
        case "CAUTION": return "exclamationmark.triangle.fill"
        default:        return "checkmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                Text(alert.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(accent)

            Text(alert.message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = alert.plannedDetail {
                Text("✓ \(detail)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }

            HStack(alignment: .top, spacing: 14) {
                figure("Quedaría", alert.balanceAfter.currencyString,
                       alert.canAfford ? Theme.textBody : Theme.danger)
                figure("Ahorro", "\(alert.savingsRateAfter) %", Theme.textBody)
                if let limit = alert.categoryLimit {
                    figure("Categoría",
                           "\(alert.categorySpentAfter.currencyString) / \(limit.currencyString)",
                           alert.categoryLimitExceeded ? Theme.danger : Theme.textBody)
                }
            }

            if alert.unplannedSpentThisMonth > 0 {
                Text("Este mes llevas \(alert.unplannedSpentThisMonth.currencyString) en gastos no fijos.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(alert.suggestions ?? [], id: \.self) { suggestion in
                Text("· \(suggestion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func figure(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

/// Pide el aviso cuando el importe se queda quieto, para no preguntar en cada
/// tecla. Se usa con `.task(id:)`, que cancela la espera anterior al cambiar.
@MainActor
@Observable
final class SpendAlertProbe {

    /// Espera a que se pare de teclear antes de preguntar al servidor.
    private static let debounceNanos: UInt64 = 450_000_000

    private(set) var alert: SpendAlert?

    func refresh(amount: Decimal?, description: String, category: String, date: Date) async {
        guard let amount, amount > 0 else {
            alert = nil
            return
        }

        do {
            try await Task.sleep(nanoseconds: Self.debounceNanos)
        } catch {
            return      // cancelado: ha llegado otra pulsación
        }

        let trimmed = description.trimmed
        // Un fallo no se enseña: el aviso es una ayuda y no debe estorbar al
        // alta si el servidor no contesta.
        alert = try? await BudgetService.spendAlert(
            SpendAlertRequest(description: trimmed.isEmpty ? nil : trimmed,
                              amount: amount,
                              category: category,
                              date: date)
        )
    }
}
