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
        if let fixture = ProcessInfo.processInfo.environment["CAESER_TEST_HISTORY"],
           suite?.hasPrefix("Caeser-UITests-") == true {
            var library = DownloadLibrary()
            let count = fixture == "empty" ? 0 : fixture == "one" ? 1 : 12
            for index in 0..<count {
                let request = DownloadRequest(url: URL(string: "https://youtube.com/watch?v=fixture\(index)")!, source: .video,
                    quality: .best, format: .mp3, destination: FileManager.default.temporaryDirectory)
                var item = QueueItem(request: request)
                item.title = index.isMultiple(of: 2) ? "Um título comprido para conferir o alinhamento do histórico e das ações sem aumentar a janela" : "Uma música de teste"
                item.status = index.isMultiple(of: 3) ? .failed : .completed
                item.detail = "Não foi possível acessar este conteúdo. Este texto longo não deve empurrar as ações para fora da janela."
                library.items.append(item)
            }
            defaults.set(try? JSONEncoder().encode(library), forKey: "downloadLibrary.v1")
        }
        let model = DownloadViewModel(defaults: defaults)
        model.showsHistory = ProcessInfo.processInfo.environment["CAESER_TEST_HISTORY"] != nil && suite?.hasPrefix("Caeser-UITests-") == true
        _viewModel = StateObject(wrappedValue: model)
        #else
        _viewModel = StateObject(wrappedValue: DownloadViewModel())
        #endif
    }

    var body: some Scene {
        Window("Caeser", id: "main") {
            ContentView(viewModel: viewModel, updates: updates)
                .frame(minWidth: 640, minHeight: 620)
                .preferredColorScheme(.dark)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
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
