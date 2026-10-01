import SwiftUI

@main
struct DhekrShareApp: App {
    @UIApplicationDelegateAdaptor(NotificationService.self) var delegate
    @StateObject private var pairing = PairingService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(pairing)
                .environmentObject(NotificationService.shared)
                .environment(\.layoutDirection, .rightToLeft)
                .task { await pairing.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await NotificationService.shared.refreshPermission()
                            await pairing.refresh()
                        }
                    }
                }
        }
    }
}
