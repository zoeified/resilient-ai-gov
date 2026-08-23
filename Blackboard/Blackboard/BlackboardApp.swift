import SwiftUI

@main
struct BlackboardApp: App {

    @StateObject private var store = BoardStore.shared
    @State private var pendingDestination: DeepLink.Destination?

    var body: some Scene {
        WindowGroup {
            BoardScreen(store: store, pendingDestination: $pendingDestination)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onOpenURL { url in
                    pendingDestination = DeepLink.destination(for: url)
                }
        }
    }
}
