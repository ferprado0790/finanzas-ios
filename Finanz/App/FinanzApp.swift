import SwiftUI

@main
struct FinanzApp: App {

    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
                .tint(Theme.primaryLight)
                .onOpenURL { url in
                    session.handle(url: url)
                }
        }
    }
}
