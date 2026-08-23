import SwiftUI

@main
struct BlackboardApp: App {

    @StateObject private var store = BoardStore.shared
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // A wipe from the widget, or a note added by Siri, happened in
                // another process — pick it up.
                store.reloadFromDisk()
            case .inactive, .background:
                store.saveNow()
            @unknown default:
                break
            }
        }
    }
}
