import AppKit
import Foundation
import SwiftUI

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = "" {
        didSet {
            errorMessage = nil
            inputMessage = nil
            if DownloadBatch.links(in: urlText).count == 1, DownloadInput.isSpotify(urlText), source != .spotify {
                source = .spotify
            } else { schedulePreview() }
        }
    }
    @Published var source: DownloadSource = .video {
        didSet { guard source != oldValue else { return }; errorMessage = nil; loadPreferences(); schedulePreview() }
    }
    @Published var quality: VideoQuality = .best { didSet { savePreferences() } }
    @Published var format: VideoFormat = .automatic { didSet { savePreferences() } }
    @Published var destinationURL: URL { didSet { savePreferences() } }
    @Published private(set) var preview: MediaPreview?
    @Published private(set) var isLoadingPreview = false
    @Published private(set) var previewError: String?
    @Published private(set) var inputMessage: String?
    @Published private(set) var library = DownloadLibrary()
    @Published var showsHistory = false
    @Published private(set) var persistenceMessage: String?
    @Published private(set) var isDownloading = false
    @Published private(set) var isInstalling = false
    @Published private(set) var progress: Double?
    @Published private(set) var statusMessage = "Pronto para o próximo download"
    @Published private(set) var speedText = ""
    @Published private(set) var etaText = ""
    @Published private(set) var logLines: [String] = []
    @Published private(set) var logRevision = 0
    @Published private(set) var dependencyInfo = DependencyLocator.locate()
    @Published private(set) var hasResult = false
    @Published private(set) var succeeded = false
    @Published var errorMessage: String?

    private var downloadProcess: (any DownloadRunning)?
    private var previewTask: Task<Void, Never>?
    private var previewID = UUID()
    private var activeID: UUID?
    private var runID = UUID()
    private var restoringPreferences = false
    private let defaults: UserDefaults
    private let locateTools: () -> DependencyInfo
    private let makeProcess: () -> any DownloadRunning
    private let previewLoader: @Sendable (URL, DownloadSource, DependencyInfo) async throws -> MediaPreview
    private var wasCancelled = false
    private var activeSource: DownloadSource = .video
    private var activeTool = "yt-dlp"
    private var operation: Operation = .download
    private var errorReportDirectory: URL?
    private var spotifyError: String?
    private var spotifyProcessedTracks = 0
    private var lastDestination: URL?

    private enum Operation { case download, createEnvironment, installSpotify }

    init(defaults: UserDefaults = .standard,
         locateTools: @escaping () -> DependencyInfo = DependencyLocator.locate,
         makeProcess: @escaping () -> any DownloadRunning = { DownloadProcess() },
         previewLoader: @escaping @Sendable (URL, DownloadSource, DependencyInfo) async throws -> MediaPreview = {
             try await MediaPreviewService().fetch(url: $0, source: $1, tools: $2)
         }) {
        self.defaults = defaults
        self.locateTools = locateTools
        self.makeProcess = makeProcess
        self.previewLoader = previewLoader
        let saved = defaults.string(forKey: "downloadDestination")
        destinationURL = saved.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        dependencyInfo = locateTools()
        loadPreferences()
        if let data = defaults.data(forKey: "downloadLibrary.v1") {
            do {
                library = try JSONDecoder().decode(DownloadLibrary.self, from: data)
                library.recoverAfterLaunch()
            } catch {
                persistenceMessage = "Não consegui restaurar a fila anterior. Seus arquivos baixados continuam na pasta de destino."
            }
        }
    }

    var isBusy: Bool { isDownloading || isInstalling }
    var effectiveFormat: VideoFormat { source == .spotify ? .mp3 : format }
    var canStartDownload: Bool {
        !isInstalling && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var dependenciesReady: Bool { dependencyInfo.isReady(for: source) }
    var dependencyMessage: String {
        let missing = dependencyInfo.missing(for: source)
        if DependencyLocator.isBundledDistribution {
            return missing.isEmpty ? "Tudo pronto para baixar · ferramentas incluídas"
                : "Pacote incompleto: " + missing.joined(separator: " e ")
        }
        return missing.isEmpty ? "Tudo pronto para baixar" : "Falta instalar: " + missing.joined(separator: " e ")
    }
    var canRevealDownload: Bool { succeeded && operation == .download && lastDestination != nil }

    var queuedItems: [QueueItem] { library.pending }
    var history: [QueueItem] { library.history }
    var isQueuePaused: Bool { library.isPaused }
    var inputLinkCount: Int { DownloadBatch.links(in: urlText).count }

    func refreshDependencies() { dependencyInfo = locateTools() }

    private func loadPreferences() {
        restoringPreferences = true
        defer { restoringPreferences = false }
        if let data = defaults.data(forKey: "preferences.\(source.rawValue)"),
           let preferences = try? JSONDecoder().decode(DownloadPreferences.self, from: data) {
            quality = preferences.quality
            format = preferences.format
            destinationURL = preferences.destination
        } else {
            quality = .best
            format = .automatic
            destinationURL = defaults.string(forKey: "downloadDestination").map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
    }

    private func savePreferences() {
        guard !restoringPreferences else { return }
        let preferences = DownloadPreferences(quality: quality, format: format, destination: destinationURL)
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: "preferences.\(source.rawValue)")
        }
    }

    private func persistLibrary() {
        library.trimHistory()
        do {
            defaults.set(try JSONEncoder().encode(library), forKey: "downloadLibrary.v1")
            persistenceMessage = nil
        } catch {
            persistenceMessage = "Não consegui salvar a fila. Mantenha o app aberto até os downloads terminarem."
        }
    }

    func schedulePreview(immediate: Bool = false) {
        previewTask?.cancel()
        previewID = UUID()
        preview = nil
        previewError = nil
        isLoadingPreview = false
        guard inputLinkCount == 1, let url = try? DownloadInput.validatedURL(urlText, source: source) else { return }
        let id = previewID, selectedSource = source, tools = locateTools(), loader = previewLoader
        isLoadingPreview = true
        previewTask = Task { [weak self] in
            do {
                if !immediate { try await Task.sleep(for: .milliseconds(800)) }
                let result = try await loader(url, selectedSource, tools)
                guard !Task.isCancelled, let self, self.previewID == id else { return }
                self.preview = result
                self.isLoadingPreview = false
            } catch {
                guard !Task.isCancelled, let self, self.previewID == id else { return }
                self.previewError = (error as? PreviewError)?.localizedDescription ?? PreviewError.unavailable.localizedDescription
                self.isLoadingPreview = false
            }
        }
    }

    func pasteLink() {
        guard !isInstalling else { return }
        if let value = NSPasteboard.general.string(forType: .string) {
            urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func chooseDestination() {
        guard !isInstalling else { return }
        let panel = NSOpenPanel()
        panel.title = "Escolha a pasta de destino"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = destinationURL
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        destinationURL = selectedURL
        defaults.set(selectedURL.path, forKey: "downloadDestination")
    }

    func revealDownload() {
        if let lastDestination { NSWorkspace.shared.open(lastDestination) }
    }

    func startDownload() {
        guard canStartDownload else { return }
        do {
            let requests = try DownloadBatch.requests(text: urlText, source: source, quality: quality,
                                                      format: format, destination: destinationURL, preview: preview)
            var additions: [QueueItem] = []
            var skipped = 0
            for request in requests {
                let existing = library.items + additions
                if existing.contains(where: { $0.request.duplicateKey == request.duplicateKey &&
                    ($0.status.isPending || ($0.status == .completed && !$0.files.isEmpty &&
                        $0.files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })) }) {
                    skipped += 1
                } else { additions.append(QueueItem(request: request)) }
            }
            guard queuedItems.count + additions.count <= 100 else { throw LibraryError.queueFull }
            library.items += additions
            // A new explicit download also resumes a restored or manually paused queue.
            // Invalid input and duplicate-only submissions leave its pause state intact.
            if !additions.isEmpty { library.isPaused = false }
            savePreferences()
            persistLibrary()
            urlText = ""
            inputMessage = skipped > 0 ? "\(skipped) link(s) já estavam na fila ou no histórico. Para repetir um download, use o Histórico." : nil
            startNextIfNeeded()
        } catch { inputMessage = error.localizedDescription }
    }

    func toggleQueuePause() {
        library.isPaused.toggle()
        persistLibrary()
        startNextIfNeeded()
    }

    func removeFromQueue(_ id: UUID) {
        library.items.removeAll { $0.id == id && $0.status == .waiting }
        persistLibrary()
    }

    func moveInQueue(_ id: UUID, earlier: Bool) {
        library.moveWaiting(id, earlier: earlier)
        persistLibrary()
    }

    func retry(_ item: QueueItem) {
        guard !library.items.contains(where: { $0.status.isPending && $0.request.duplicateKey == item.request.duplicateKey }),
              queuedItems.count < 100 else { return }
        library.items.append(QueueItem(request: item.request))
        persistLibrary()
        startNextIfNeeded()
    }

    func reveal(_ item: QueueItem) {
        let existing = item.files.filter { FileManager.default.fileExists(atPath: $0.path) }
        if !existing.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(existing) }
        else { NSWorkspace.shared.open(item.request.destination) }
    }

    func clearHistory() {
        // This removes records only, never any downloaded file.
        library.items.removeAll { !$0.status.isPending }
        persistLibrary()
    }

    func stopForQuit() {
        previewTask?.cancel()
        library.isPaused = true
        persistLibrary()
        downloadProcess?.cancel()
    }

    private func startNextIfNeeded() {
        guard !isBusy, !library.isPaused,
              let item = library.items.first(where: { $0.status == .waiting }) else { return }
        activeID = item.id
        updateActive { $0.status = .downloading; $0.detail = "Preparando download…" }
        persistLibrary()
        if !startItem(item) {
            updateActive { $0.status = .failed; $0.detail = errorMessage ?? "Não consegui iniciar o download."; $0.finishedAt = Date() }
            activeID = nil
            hasResult = true
            persistLibrary()
            Task { [weak self] in self?.startNextIfNeeded() }
        }
    }

    private func updateActive(_ change: (inout QueueItem) -> Void) {
        guard let index = library.items.firstIndex(where: { $0.id == activeID }) else { return }
        change(&library.items[index])
    }

    private func startItem(_ item: QueueItem) -> Bool {
        let request = item.request
        let source = request.source, destinationURL = request.destination
        let quality = request.quality, format = request.format, url = request.url
        errorMessage = nil
        refreshDependencies()
        if DependencyLocator.isBundledDistribution && !dependencyInfo.isReady(for: source) {
            showError("O pacote do Caeser está incompleto. Baixe novamente o aplicativo completo; não é necessário instalar Homebrew.")
            return false
        }

        guard let ffmpeg = dependencyInfo.ffmpeg else {
            showError("Instale o FFmpeg com brew install ffmpeg e clique em Verificar ferramentas.")
            return false
        }
        let executable: URL
        var arguments: [String]
        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            guard FileManager.default.isWritableFile(atPath: destinationURL.path) else {
                showError("Esta pasta não permite salvar arquivos. Escolha outra pasta de destino.")
                return false
            }
            if source == .spotify {
                guard let spotDL = dependencyInfo.spotDL else {
                    showError("Instale o suporte ao Spotify no botão abaixo e tente novamente.")
                    return false
                }
                executable = spotDL
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Caeser-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                errorReportDirectory = directory
                arguments = SpotifyDownloadOptions(
                    url: url, ffmpeg: ffmpeg,
                    errorReport: directory.appendingPathComponent("errors.txt"),
                    matchedURL: PreviewParser.youtubeURL(request.preview?.matchedURL?.absoluteString)
                ).arguments
            } else {
                guard let ytDLP = dependencyInfo.ytDLP else {
                    showError("Instale o yt-dlp com brew install yt-dlp e clique em Verificar ferramentas.")
                    return false
                }
                executable = ytDLP
                arguments = DownloadOptions(url: url, destination: destinationURL, quality: quality, format: format).arguments
                // Pass the exact FFmpeg location even when Xcode has a minimal PATH.
                arguments.insert(contentsOf: ["--ffmpeg-location", ffmpeg.deletingLastPathComponent().path], at: 0)
            }
        } catch {
            showError("Não consegui preparar a pasta de destino: \(error.localizedDescription)")
            return false
        }

        activeSource = source
        activeTool = source == .spotify ? "spotDL" : "yt-dlp"
        operation = .download
        isDownloading = true
        resetRun()
        lastDestination = destinationURL
        statusMessage = source == .spotify ? "Identificando as músicas do Spotify…" : "Preparando download…"
        appendLog(source == .spotify
            ? "Spotify identifica as músicas. O áudio será buscado no YouTube e salvo em MP3."
            : "Iniciando yt-dlp…")
        appendLog("Destino: \(destinationURL.path)")
        run(executable: executable, arguments: arguments)
        return true
    }

    func installSpotifySupport() {
        guard !isBusy, queuedItems.isEmpty else { return }
        if DependencyLocator.isBundledDistribution {
            refreshDependencies()
            if dependencyInfo.spotDL == nil {
                showError("O suporte ao Spotify deveria estar incluído. Baixe novamente o pacote completo do Caeser.")
            }
            return
        }
        guard let python = DependencyLocator.findExecutable(named: "python3") else {
            showError("Instale o Python com brew install python e tente instalar o suporte novamente.")
            return
        }
        isInstalling = true
        activeTool = "instalador do Spotify"
        resetRun()
        statusMessage = "Preparando o suporte ao Spotify…"
        appendLog("Instalando spotDL em um ambiente separado, fora do aplicativo.")
        let directory = DependencyLocator.spotifyEnvironment
        do {
            try FileManager.default.createDirectory(
                at: directory.deletingLastPathComponent(), withIntermediateDirectories: true
            )
        } catch {
            isInstalling = false
            showError("Não consegui preparar a instalação: \(error.localizedDescription)")
            return
        }
        operation = .createEnvironment
        run(executable: python, arguments: ["-m", "venv", directory.path])
    }

    func cancelDownload() {
        guard isBusy else { return }
        wasCancelled = true
        statusMessage = "Cancelando…"
        updateActive { $0.detail = "Cancelando…" }
        downloadProcess?.cancel()
    }

    func clearLogs() {
        guard !isBusy else { return }
        logLines.removeAll()
        logRevision += 1
    }

    func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logLines.joined(separator: "\n"), forType: .string)
    }

    private func resetRun() {
        wasCancelled = false
        hasResult = false
        succeeded = false
        progress = nil
        speedText = ""
        etaText = ""
        errorMessage = nil
        spotifyError = nil
        spotifyProcessedTracks = 0
        logLines.removeAll()
        logRevision += 1
    }

    private func run(executable: URL, arguments: [String]) {
        let process = makeProcess()
        let id = UUID()
        runID = id
        downloadProcess = process
        do {
            try process.start(
                executableURL: executable, arguments: arguments,
                environment: DependencyLocator.processEnvironment(),
                currentDirectoryURL: isInstalling ? DependencyLocator.spotifyEnvironment.deletingLastPathComponent() : lastDestination,
                output: { [weak self] line in
                    DispatchQueue.main.async {
                        guard let self, self.runID == id else { return }
                        self.receive(line: line)
                    }
                },
                completion: { [weak self] outcome in
                    DispatchQueue.main.async {
                        guard let self, self.runID == id else { return }
                        self.finish(outcome: outcome)
                    }
                }
            )
        } catch { finish(outcome: .failed(error.localizedDescription)) }
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 600 { logLines.removeFirst(logLines.count - 600) }
        logRevision += 1
    }

    private func receive(line: String) {
        let clean = line.replacingOccurrences(of: #"\x1B\[[0-?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        appendLog(clean)
        guard !wasCancelled, !isInstalling else { return }
        defer { updateActive { $0.progress = progress; $0.detail = statusMessage } }

        if clean.hasPrefix("CAESER_TITLE:"),
           let data = clean.dropFirst("CAESER_TITLE:".count).data(using: .utf8),
           let title = try? JSONDecoder().decode(String.self, from: data) {
            updateActive { $0.title = title }
            return
        }
        if clean.hasPrefix("CAESER_FILE:"),
           let data = clean.dropFirst("CAESER_FILE:".count).data(using: .utf8),
           let path = try? JSONDecoder().decode(String.self, from: data), path.hasPrefix("/") {
            updateActive { if !$0.files.contains(URL(fileURLWithPath: path)) { $0.files.append(URL(fileURLWithPath: path)) } }
            return
        }

        if activeSource == .spotify {
            let event = SpotifyLogEvent(line: clean)
            if event.isError { spotifyError = event.message }
            if let completed = event.completed, let total = event.total, total > 0 {
                spotifyProcessedTracks = completed
                progress = min(Double(completed) / Double(total), 0.99)
                speedText = "\(completed) de \(total) músicas processadas"
            }
            if event.message.contains("Searching for song") { statusMessage = "Buscando a versão correspondente no YouTube…" }
            else if event.message.contains("Downloading") { statusMessage = "Baixando áudio do YouTube…" }
            else if event.message.contains("Converting") { statusMessage = "Convertendo para MP3…" }
            else if event.message.contains("Embedding metadata") { statusMessage = "Adicionando capa e informações…" }
            else if event.message.hasPrefix("Downloaded") { statusMessage = "Música salva. Preparando a próxima…" }
            return
        }

        if clean.hasPrefix("download:") {
            let values = clean.dropFirst("download:".count).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if let raw = values.first, let percent = parsePercent(raw) {
                progress = min(max(percent / 100, 0), 1)
                statusMessage = "Baixando… \(raw.trimmingCharacters(in: .whitespaces))"
            }
            if values.count > 3, !values[3].contains("N/A") { speedText = values[3] }
            if values.count > 4, !values[4].contains("N/A") { etaText = "Tempo restante: \(values[4]) s" }
        } else if clean.contains("[Merger]") {
            progress = nil
            statusMessage = "Unindo vídeo e áudio…"
        } else if clean.contains("[ExtractAudio]") {
            progress = nil
            statusMessage = "Convertendo para MP3…"
        }
    }

    private func finish(outcome: ProcessOutcome) {
        downloadProcess = nil
        if !wasCancelled, case .exited(0) = outcome, operation == .createEnvironment {
            operation = .installSpotify
            statusMessage = "Instalando spotDL…"
            let python = DependencyLocator.spotifyEnvironment.appendingPathComponent("bin/python")
            run(executable: python, arguments: [
                "-m", "pip", "install", "--disable-pip-version-check", "--no-input",
                "--no-cache-dir", "spotdl>=4.5.2,<5"
            ])
            return
        }

        let installing = isInstalling
        isDownloading = false
        isInstalling = false
        hasResult = true
        let report = errorReportDirectory.flatMap {
            try? String(contentsOf: $0.appendingPathComponent("errors.txt"), encoding: .utf8)
        }?.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            if let directory = errorReportDirectory { try? FileManager.default.removeItem(at: directory) }
            errorReportDirectory = nil
            refreshDependencies()
            if !installing, activeID != nil {
                // spotDL logs completion rather than machine-readable final paths. A single
                // track's stable Spotify ID identifies its output without guessing a title.
                if succeeded, activeSource == .spotify,
                   let item = library.items.first(where: { $0.id == activeID }),
                   item.request.url.path.contains("/track/"),
                   let files = try? FileManager.default.contentsOfDirectory(at: item.request.destination,
                                                                          includingPropertiesForKeys: nil) {
                    let suffix = "[\(item.request.url.lastPathComponent)].mp3"
                    updateActive { $0.files = files.filter { $0.lastPathComponent.hasSuffix(suffix) } }
                }
                updateActive {
                    $0.status = wasCancelled ? .cancelled : (succeeded ? .completed : .failed)
                    $0.progress = succeeded ? 1 : nil
                    $0.detail = errorMessage ?? statusMessage
                    $0.finishedAt = Date()
                }
                activeID = nil
                persistLibrary()
                Task { [weak self] in self?.startNextIfNeeded() }
            }
        }
        if wasCancelled {
            progress = nil
            statusMessage = installing ? "Instalação cancelada" : "Download cancelado"
            appendLog(statusMessage)
            return
        }
        switch outcome {
        case .failed(let message):
            progress = nil
            showError("Não consegui iniciar \(activeTool): \(message)")
        case .exited(let status):
            let reportedError = (report?.isEmpty == false ? report : nil)
                ?? (report == nil ? spotifyError : nil)
                ?? (!installing && activeSource == .spotify && spotifyProcessedTracks == 0
                    ? "Nenhuma música foi processada. Confira se o link aponta para uma música ou coleção pública disponível."
                    : nil)
            if status == 0 && (installing || activeSource != .spotify || reportedError == nil) {
                progress = 1
                succeeded = true
                statusMessage = installing ? "Spotify pronto para usar" : "Download concluído"
                appendLog(statusMessage)
            } else {
                progress = nil
                let detail = reportedError.map { "\n\($0.prefix(350))" } ?? ""
                showError(installing
                    ? "Não consegui instalar o spotDL. Verifique a conexão e tente novamente. Os detalhes estão no registro."
                    : "O download não foi concluído. \(activeSource == .spotify ? "Confira se o link é público e tente novamente; a busca também pode falhar por limites do Spotify ou do YouTube." : "Confira o link e sua conexão e tente novamente.")\(detail)")
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        statusMessage = "Precisa de atenção"
        succeeded = false
        appendLog("Erro: \(message)")
    }

    private func parsePercent(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
