import SwiftUI

@main
struct ChargeApp: App {
    @StateObject private var model = ChargeModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
