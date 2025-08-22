import SwiftUI
import FirebaseCore

@main
struct KasookooSDKiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .onAppear {
                    // App icon is configured via Assets.xcassets/AppIcon.appiconset
                }
        }
    }
}
