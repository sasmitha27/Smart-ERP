import SwiftUI

@main
struct SmartERPApp: App {
    @State private var store = DemoStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.blue)
        }
    }
}
