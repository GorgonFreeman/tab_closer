import SwiftUI

@main
struct TabCloserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
