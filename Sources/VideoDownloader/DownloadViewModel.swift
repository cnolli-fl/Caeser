import Foundation
import SwiftUI

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var quality: VideoQuality = .best
    @Published var format: VideoFormat = .automatic
    @Published var destinationURL: URL
    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double?
    @Published private(set) var statusMessage = "Pronto para baixar"
    @Published private(set) var speedText = ""
    @Published private(set) var etaText = ""
    @Published private(set) var logLines: [String] = []
    @Published private(set) var dependencyInfo = DependencyLocator.locate()
    @Published var errorMessage: String?

    private var downloadProcess: DownloadProcess?
    private var wasCancelled = false

    init() {
        destinationURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var canStartDownload: Bool {
        !isDownloading && !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshDependencies() {
        dependencyInfo = DependencyLocator.locate()
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Escolha a pasta de destino"
        panel.message = "Os arquivos baixados serão salvos nesta pasta."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = destinationURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        destinationURL = selectedURL
    }

    func startDownload() {
        guard !isDownloading else { return }
        errorMessage = nil
        refreshDependencies()

        guard let ytDLPURL = dependencyInfo.ytDLP else {
            showError("Não encontrei o yt-dlp. Instale-o com Homebrew usando: brew install yt-dlp")
            return
        }

        guard dependencyInfo.ffmpeg != nil else {
            showError("Não encontrei o FFmpeg. Instale-o com Homebrew usando: brew install ffmpeg")
            return
        }

        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let videoURL = URL(string: trimmedURL),
              let scheme = videoURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            showError("Cole uma URL válida começando com http:// ou https://.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        } catch {
            showError("Não foi possível acessar a pasta de destino: \(error.localizedDescription)")
            return
        }

        let options = DownloadOptions(
            url: videoURL,
            destination: destinationURL,
            quality: quality,
            format: format
        )

        let process = DownloadProcess()
        downloadProcess = process
        isDownloading = true
        wasCancelled = false
        progress = nil
        speedText = ""
        etaText = ""
        logLines = ["Iniciando yt-dlp…", "Destino: \(destinationURL.path)"]
        statusMessage = "Preparando download…"

        var environment = ProcessInfo.processInfo.environment
        if let ffmpegURL = dependencyInfo.ffmpeg {
            let ffmpegDirectory = ffmpegURL.deletingLastPathComponent().path
            let currentPath = environment["PATH"] ?? ""
            environment["PATH"] = "\(ffmpegDirectory):\(currentPath)"
        }

        do {
            try process.start(
                executableURL: ytDLPURL,
                arguments: options.arguments,
                environment: environment,
                output: { [weak self] line in
                    Task { @MainActor [weak self] in
                        self?.receive(line: line)
                    }
                },
                completion: { [weak self] outcome in
                    Task { @MainActor [weak self] in
                        self?.finish(outcome: outcome)
                    }
                }
            )
        } catch {
            finish(outcome: .failed(error.localizedDescription))
        }
    }

    func cancelDownload() {
        guard isDownloading else { return }
        wasCancelled = true
        statusMessage = "Cancelando…"
        downloadProcess?.cancel()
    }

    func clearLogs() {
        guard !isDownloading else { return }
        logLines.removeAll()
    }

    private func receive(line: String) {
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLine.isEmpty else { return }
        logLines.append(cleanLine)

        if cleanLine.hasPrefix("download:") {
            let values = cleanLine.dropFirst("download:".count).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            if let percentText = values.first,
               let percent = parsePercent(percentText) {
                progress = percent / 100
                statusMessage = "Baixando… \(percentText.trimmingCharacters(in: .whitespaces))"
            }
            if values.count > 3 { speedText = "Velocidade: \(values[3])" }
            if values.count > 4 { etaText = "Tempo restante: \(values[4])" }
            return
        }

        if let percent = parsePercentFromStandardLine(cleanLine) {
            progress = percent / 100
            statusMessage = "Baixando… \(formatPercent(percent))"
        } else if cleanLine.contains("[Merger]") || cleanLine.contains("Merging formats") {
            statusMessage = "Mesclando vídeo e áudio com FFmpeg…"
        } else if cleanLine.contains("Destination:") {
            statusMessage = "Salvando arquivo…"
        }
    }

    private func finish(outcome: ProcessOutcome) {
        isDownloading = false
        downloadProcess = nil

        switch outcome {
        case .failed(let message):
            statusMessage = "Falha ao iniciar"
            showError("Não foi possível iniciar o yt-dlp: \(message)")
        case .exited(let status):
            if wasCancelled {
                statusMessage = "Download cancelado"
                logLines.append("Download cancelado pelo usuário.")
            } else if status == 0 {
                progress = 1
                statusMessage = "Download concluído"
                logLines.append("Download concluído com sucesso.")
            } else {
                statusMessage = "Download encerrado com erro"
                showError("O yt-dlp terminou com código \(status). Consulte os logs para ver os detalhes.")
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        logLines.append("Erro: \(message)")
    }

    private func parsePercent(_ value: String) -> Double? {
        let number = value
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(number)
    }

    private func parsePercentFromStandardLine(_ line: String) -> Double? {
        guard let percentRange = line.range(of: "%") else { return nil }
        let beforePercent = line[..<percentRange.lowerBound]
        let number = beforePercent.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "," }).last.map(String.init) ?? ""
        return parsePercent(number)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}
