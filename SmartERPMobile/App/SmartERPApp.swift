import SwiftUI
import GoogleSignIn

@main
struct SmartERPApp: App {
    @State private var store = DemoStore()
    @State private var auth = GoogleAuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .onOpenURL { _ = GIDSignIn.sharedInstance.handle($0) }
                .tint(Theme.blue)
        }
    }
}
