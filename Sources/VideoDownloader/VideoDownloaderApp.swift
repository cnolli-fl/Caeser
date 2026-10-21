import SwiftUI

@main
struct CaeserApp: App {
    @StateObject private var viewModel = DownloadViewModel()

    var body: some Scene {
        Window("Caeser", id: "main") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 640, minHeight: 620)
        }
        .defaultSize(width: 820, height: 760)
        .commands {
            CommandMenu("Downloads") {
                Button("Colar link") { viewModel.pasteLink() }
                    .keyboardShortcut("l", modifiers: .command)
                    .disabled(viewModel.isBusy)
                Button("Baixar") { viewModel.startDownload() }
                    .keyboardShortcut("d", modifiers: .command)
                    .disabled(!viewModel.canStartDownload)
                Button("Cancelar") { viewModel.cancelDownload() }
                    .disabled(!viewModel.isBusy)
                Divider()
                Button("Alterar pasta…") { viewModel.chooseDestination() }
                    .disabled(viewModel.isBusy)
                Button("Mostrar no Finder") { viewModel.revealDownload() }
                    .disabled(!viewModel.canRevealDownload)
                Divider()
                Button("Verificar ferramentas") { viewModel.refreshDependencies() }
                Button("Instalar suporte ao Spotify…") { viewModel.installSpotifySupport() }
                    .disabled(viewModel.isBusy || viewModel.dependencyInfo.spotDL != nil)
                Button("Copiar registro") { viewModel.copyLogs() }
                    .disabled(viewModel.logLines.isEmpty)
                Button("Limpar registro") { viewModel.clearLogs() }
                    .disabled(viewModel.isBusy)
            }
        }
    }
}
