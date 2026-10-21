import AppKit
import Foundation
import SwiftUI

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = "" {
        didSet {
            errorMessage = nil
            if DownloadInput.isSpotify(urlText) { source = .spotify }
        }
    }
    @Published var source: DownloadSource = .video { didSet { errorMessage = nil } }
    @Published var quality: VideoQuality = .best
    @Published var format: VideoFormat = .automatic
    @Published var destinationURL: URL
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

    private var downloadProcess: DownloadProcess?
    private var wasCancelled = false
    private var activeSource: DownloadSource = .video
    private var activeTool = "yt-dlp"
    private var operation: Operation = .download
    private var errorReportDirectory: URL?
    private var spotifyError: String?
    private var spotifyProcessedTracks = 0
    private var lastDestination: URL?

    private enum Operation { case download, createEnvironment, installSpotify }

    init() {
        let saved = UserDefaults.standard.string(forKey: "downloadDestination")
        destinationURL = saved.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var isBusy: Bool { isDownloading || isInstalling }
    var effectiveFormat: VideoFormat { source == .spotify ? .mp3 : format }
    var canStartDownload: Bool {
        !isBusy && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var dependenciesReady: Bool { dependencyInfo.isReady(for: source) }
    var dependencyMessage: String {
        let missing = dependencyInfo.missing(for: source)
        return missing.isEmpty ? "Tudo pronto para baixar" : "Falta instalar: " + missing.joined(separator: " e ")
    }
    var canRevealDownload: Bool { succeeded && operation == .download && lastDestination != nil }

    func refreshDependencies() { dependencyInfo = DependencyLocator.locate() }

    func pasteLink() {
        guard !isBusy else { return }
        if let value = NSPasteboard.general.string(forType: .string) {
            urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func chooseDestination() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = "Escolha a pasta de destino"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = destinationURL
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        destinationURL = selectedURL
        UserDefaults.standard.set(selectedURL.path, forKey: "downloadDestination")
    }

    func revealDownload() {
        if let lastDestination { NSWorkspace.shared.open(lastDestination) }
    }

    func startDownload() {
        guard !isBusy else { return }
        errorMessage = nil
        refreshDependencies()
        let url: URL
        do { url = try DownloadInput.validatedURL(urlText, source: source) }
        catch { showError(error.localizedDescription); return }

        guard let ffmpeg = dependencyInfo.ffmpeg else {
            showError("Instale o FFmpeg com brew install ffmpeg e clique em Verificar ferramentas.")
            return
        }
        let executable: URL
        var arguments: [String]
        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            guard FileManager.default.isWritableFile(atPath: destinationURL.path) else {
                showError("Esta pasta não permite salvar arquivos. Escolha outra pasta de destino.")
                return
            }
            if source == .spotify {
                guard let spotDL = dependencyInfo.spotDL else {
                    showError("Instale o suporte ao Spotify no botão abaixo e tente novamente.")
                    return
                }
                executable = spotDL
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Caeser-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                errorReportDirectory = directory
                arguments = SpotifyDownloadOptions(
                    url: url, ffmpeg: ffmpeg,
                    errorReport: directory.appendingPathComponent("errors.txt")
                ).arguments
            } else {
                guard let ytDLP = dependencyInfo.ytDLP else {
                    showError("Instale o yt-dlp com brew install yt-dlp e clique em Verificar ferramentas.")
                    return
                }
                executable = ytDLP
                arguments = DownloadOptions(url: url, destination: destinationURL, quality: quality, format: format).arguments
                // Pass the exact FFmpeg location even when Xcode has a minimal PATH.
                arguments.insert(contentsOf: ["--ffmpeg-location", ffmpeg.deletingLastPathComponent().path], at: 0)
            }
        } catch {
            showError("Não consegui preparar a pasta de destino: \(error.localizedDescription)")
            return
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
    }

    func installSpotifySupport() {
        guard !isBusy else { return }
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
        let process = DownloadProcess()
        downloadProcess = process
        do {
            try process.start(
                executableURL: executable, arguments: arguments,
                environment: DependencyLocator.processEnvironment(),
                currentDirectoryURL: isInstalling ? DependencyLocator.spotifyEnvironment.deletingLastPathComponent() : destinationURL,
                output: { [weak self] line in
                    DispatchQueue.main.async { self?.receive(line: line) }
                },
                completion: { [weak self] outcome in
                    DispatchQueue.main.async { self?.finish(outcome: outcome) }
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
