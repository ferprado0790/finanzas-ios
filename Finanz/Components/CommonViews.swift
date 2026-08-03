import SwiftUI

// MARK: - Tarjeta base

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var borderColor: Color = Theme.border
    var borderWidth: CGFloat = 1
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

// MARK: - Encabezado de sección

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .kerning(1)
            .foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Barra de progreso

struct ProgressBar: View {
    let value: Double          // 0...1
    var color: Color = Theme.primary
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.background)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: value)
    }
}

// MARK: - Botón principal

struct PrimaryButton: View {
    let title: String
    var gradient: LinearGradient = Theme.primaryGradient
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(isLoading ? "Cargando…" : title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(isEnabled && !isLoading ? AnyShapeStyle(gradient) : AnyShapeStyle(Theme.borderStrong))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Chip seleccionable

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var accent: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? accent : Theme.textMuted)
                .background(isSelected ? accent.opacity(0.13) : Theme.background)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? accent : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selector de mes

struct MonthSelector: View {
    @Binding var month: Int
    @Binding var year: Int
    var accent: Color = Theme.primaryLight

    var body: some View {
        HStack(spacing: 16) {
            stepButton(system: "chevron.left") { shift(-1) }

            Text("\(Formatters.monthNames[max(0, min(11, month - 1))]) \(String(year))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textBody)
                .frame(minWidth: 150)

            stepButton(system: "chevron.right") { shift(1) }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shift(_ delta: Int) {
        var next = month + delta
        if next < 1 { next = 12; year -= 1 }
        else if next > 12 { next = 1; year += 1 }
        month = next
    }
}

// MARK: - Estados

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Theme.textFaint)
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textBody)
                if let retry {
                    Button("Reintentar", action: retry)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primaryLight)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.warning.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Campos de formulario con el estilo de la app

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DarkTextFieldStyle: TextFieldStyle {
    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(Theme.textPrimary)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    /// Fondo oscuro a pantalla completa, usado por todas las pantallas.
    func finanzBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}
