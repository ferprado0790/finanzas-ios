import SwiftUI

/// Decide qué mostrar según el estado de sesión (equivale al render condicional de `App.jsx`).
struct RootView: View {

    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .finanzBackground()
        .task {
            if session.phase == .launching {
                await session.bootstrap()
            }
        }
    }
}

/// Pantalla de carga inicial mientras se valida el JWT guardado.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("💰").font(.system(size: 44))
            Text("Cargando…")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .finanzBackground()
    }
}
