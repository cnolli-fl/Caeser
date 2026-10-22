import SwiftUI

@main
struct CaeserApp: App {
    @StateObject private var viewModel: DownloadViewModel
    @StateObject private var updates = ReleaseUpdateModel()
    @NSApplicationDelegateAdaptor(CaeserAppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        // UI checks use an isolated preferences domain, never the person's real history.
        let suite = ProcessInfo.processInfo.environment["CAESER_TEST_SUITE"]
        let defaults = suite.flatMap { $0.hasPrefix("Caeser-UITests-") ? UserDefaults(suiteName: $0) : nil } ?? .standard
        _viewModel = StateObject(wrappedValue: DownloadViewModel(defaults: defaults))
        #else
        _viewModel = StateObject(wrappedValue: DownloadViewModel())
        #endif
    }

    var body: some Scene {
        Window("Caeser", id: "main") {
            ContentView(viewModel: viewModel, updates: updates)
                .frame(minWidth: 640, minHeight: 620)
                .onAppear { appDelegate.viewModel = viewModel }
        }
        .defaultSize(width: 820, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Verificar atualizações…") { Task { await updates.check(manual: true) } }
                    .disabled(updates.isChecking)
            }
            CommandMenu("Downloads") {
                Button("Colar link") { viewModel.pasteLink() }
                    .keyboardShortcut("l", modifiers: .command)
                    .disabled(viewModel.isInstalling)
                Button("Baixar ou adicionar à fila") { viewModel.startDownload() }
                    .keyboardShortcut("d", modifiers: .command)
                    .disabled(!viewModel.canStartDownload)
                Button("Cancelar") { viewModel.cancelDownload() }
                    .disabled(!viewModel.isBusy)
                Button(viewModel.isQueuePaused ? "Continuar fila" : "Pausar fila") { viewModel.toggleQueuePause() }
                    .disabled(viewModel.queuedItems.isEmpty)
                Button("Atualizar prévia") { viewModel.schedulePreview(immediate: true) }
                    .disabled(viewModel.inputLinkCount != 1)
                Button("Histórico…") { viewModel.showsHistory = true }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Alterar pasta…") { viewModel.chooseDestination() }
                    .disabled(viewModel.isInstalling)
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

@MainActor
final class CaeserAppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: DownloadViewModel?
    func applicationWillTerminate(_ notification: Notification) { viewModel?.stopForQuit() }
}
