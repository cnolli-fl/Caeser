import SwiftUI

@main
struct CaeserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 680, minHeight: 650)
        }
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
        }
    }
}
