import SwiftUI

struct WelcomeView: View {
    @Environment(DemoStore.self) private var store

    var body: some View {
        NavigationStack {
            ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 86, height: 86)
                    .background(Theme.blue, in: RoundedRectangle(cornerRadius: 25))
                VStack(alignment: .leading, spacing: 8) {
                    Text("SmartERP").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Your business, in motion.").font(.title2).foregroundStyle(.secondary)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Explore a connected ERP workflow", systemImage: "checkmark.seal.fill").font(.headline)
                        Text("Create customers and products, prepare orders and purchases, receive stock, and issue demo invoices. Data stays on this device.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Label("Local demo workspace", systemImage: "iphone.gen3")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.blue)
                    }
                }
                Button { store.switchWorkspace(to: nil); store.hasEntered = true } label: {
                    Text("Explore demo").frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                NavigationLink("Sign in with Google") { GoogleLoginView() }
                    .frame(maxWidth: .infinity)
                Text("Google sign-in connects Firebase backup. Inventolo service login is not configured.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
            }
        }
    }
}
