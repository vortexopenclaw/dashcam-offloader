import SwiftUI

@main
struct DashcamOffloaderApp: App {
    init() {
        if CommandLine.arguments.contains("--smoke-test") {
            let result = SmokeTest.run()
            Foundation.exit(result ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: TransferViewModel())
                .frame(minWidth: 1180, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}
