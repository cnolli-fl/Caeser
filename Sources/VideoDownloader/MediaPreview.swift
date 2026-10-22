import Foundation

struct VideoPreview: Codable, Equatable, Sendable {
    let url: URL
    let title: String
    let creator: String
    let artworkURL: URL?
    let duration: Double?

    var durationText: String? { MediaPreview.durationText(duration) }
}

struct MediaPreview: Codable, Equatable, Sendable {
    let originalURL: URL
    let title: String
    let creator: String
    let artworkURL: URL?
    let duration: Double?
    var trackCount: Int = 1
    var matchedVideo: VideoPreview?
    var matchedURL: URL?

    var durationText: String? { Self.durationText(duration) }
    static func durationText(_ seconds: Double?) -> String? {
        guard let seconds, seconds.isFinite, seconds > 0, seconds < 31_536_000 else { return nil }
        let value = Int(seconds)
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
    }
}

enum PreviewError: LocalizedError {
    case unavailable, missingTool, timedOut, tooLarge
    var errorDescription: String? {
        switch self {
        case .unavailable: "Não consegui carregar a prévia. Confira o link ou tente novamente. Você ainda pode adicionar o link à fila."
        case .missingTool: "A prévia precisa das ferramentas de download. Confira em Detalhes e ferramentas."
        case .timedOut: "A prévia demorou mais que o esperado. Tente novamente ou adicione o link à fila."
        case .tooLarge: "Esta coleção é grande demais para a prévia. Você ainda pode adicioná-la à fila."
        }
    }
}

enum PreviewParser {
    private struct Video: Decodable {
        let title: String?
        let uploader: String?
        let channel: String?
        let thumbnail: String?
        let duration: Double?
    }
    private struct Song: Decodable {
        let name: String
        let artists: [String]
        let cover_url: String?
        let duration: Double?
        let list_name: String?
        let album_name: String?
        let download_url: String?
    }

    static func remoteImage(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func youtubeURL(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), url.scheme == "https",
              ["youtube.com", "www.youtube.com", "music.youtube.com", "youtu.be"].contains(url.host?.lowercased() ?? ""),
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func video(lines: [String], url: URL) throws -> VideoPreview {
        for line in lines.reversed() where line.hasPrefix("{") {
            if let data = line.data(using: .utf8), let item = try? JSONDecoder().decode(Video.self, from: data),
               let title = item.title, !title.isEmpty {
                return VideoPreview(url: url, title: title, creator: item.channel ?? item.uploader ?? "",
                                    artworkURL: remoteImage(item.thumbnail), duration: item.duration)
            }
        }
        throw PreviewError.unavailable
    }

    static func spotify(data: Data, url: URL) throws -> MediaPreview {
        guard data.count <= 8_000_000 else { throw PreviewError.tooLarge }
        let songs = try JSONDecoder().decode([Song?].self, from: data).compactMap { $0 }
        guard let first = songs.first else { throw PreviewError.unavailable }
        let collection = url.path.contains("/album/") || url.path.contains("/playlist/")
        return MediaPreview(originalURL: url,
                            title: collection ? (first.list_name ?? first.album_name ?? "Coleção do Spotify") : first.name,
                            creator: collection ? "\(songs.count) músicas · Spotify" : first.artists.joined(separator: ", "),
                            artworkURL: remoteImage(first.cover_url),
                            duration: songs.reduce(0) { $0 + ($1.duration ?? 0) }, trackCount: songs.count,
                            matchedURL: collection ? nil : youtubeURL(first.download_url))
    }
}

/// Owns the process through start/cancel races. A cancelled preview is fully drained
/// before its temporary directory is removed or another preview replaces it.
private final class PreviewProcess: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var process: DownloadProcess?
    private var cancelled = false
    private var timedOut = false
    private var tooLarge = false
    private var lines: [String] = []
    private var bytes = 0

    func cancel(timeout: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        timedOut = timedOut || timeout
        process?.cancel()
    }

    func execute(executable: URL, arguments: [String], environment: [String: String], directory: URL?, timeout: Double = 60) async throws -> [String] {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock(); defer { lock.unlock() }
                guard !cancelled else { continuation.resume(throwing: CancellationError()); return }
                let runner = DownloadProcess()
                process = runner
                do {
                    try runner.start(executableURL: executable, arguments: arguments, environment: environment,
                                     currentDirectoryURL: directory, output: { [self] line in
                        lock.lock(); defer { lock.unlock() }
                        bytes += line.utf8.count
                        if bytes > 8_000_000 { tooLarge = true; runner.cancel(); return }
                        lines.append(line)
                    }, completion: { [self] result in
                        lock.lock(); defer { lock.unlock() }
                        process = nil
                        if tooLarge { continuation.resume(throwing: PreviewError.tooLarge) }
                        else if timedOut { continuation.resume(throwing: PreviewError.timedOut) }
                        else if cancelled { continuation.resume(throwing: CancellationError()) }
                        else if case .exited(0) = result { continuation.resume(returning: lines) }
                        else { continuation.resume(throwing: PreviewError.unavailable) }
                    })
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                        guard let self else { return }
                        self.lock.lock(); defer { self.lock.unlock() }
                        if self.process != nil { self.cancel(timeout: true) }
                    }
                } catch {
                    process = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: { self.cancel() }
    }
}

struct MediaPreviewService: Sendable {
    func fetch(url: URL, source: DownloadSource, tools: DependencyInfo) async throws -> MediaPreview {
        let environment = DependencyLocator.processEnvironment()
        if source == .video {
            guard let tool = tools.ytDLP else { throw PreviewError.missingTool }
            let video = try await fetchVideo(url: url, tool: tool, environment: environment)
            return MediaPreview(originalURL: url, title: video.title, creator: video.creator,
                                artworkURL: video.artworkURL, duration: video.duration)
        }
        guard let tool = tools.spotDL, let ffmpeg = tools.ffmpeg else { throw PreviewError.missingTool }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Caeser-preview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let metadata = directory.appendingPathComponent("preview.spotdl")
        var arguments = ["save", url.absoluteString, "--save-file", metadata.path,
                         "--audio", "youtube", "youtube-music", "--ffmpeg", ffmpeg.path,
                         "--threads", "1", "--headless", "--simple-tui", "--log-level", "ERROR",
                         "--max-retries", "1", "--lyrics"]
        // Resolve a single track once. The very same match is used for the download.
        // Collections show metadata only; do not launch hundreds of YouTube searches.
        if url.path.contains("/track/") { arguments.append("--preload") }
        _ = try await PreviewProcess().execute(executable: tool, arguments: arguments,
                                               environment: environment, directory: directory, timeout: 120)
        try Task.checkCancellation()
        let size = try metadata.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 8_000_000 else { throw PreviewError.tooLarge }
        var preview = try PreviewParser.spotify(data: Data(contentsOf: metadata), url: url)
        if let match = preview.matchedURL, let ytDLP = tools.ytDLP {
            preview.matchedVideo = try? await fetchVideo(url: match, tool: ytDLP, environment: environment)
        }
        try Task.checkCancellation()
        return preview
    }

    private func fetchVideo(url: URL, tool: URL, environment: [String: String]) async throws -> VideoPreview {
        let lines = try await PreviewProcess().execute(executable: tool,
            arguments: ["--ignore-config", "--no-playlist", "--skip-download", "--dump-single-json",
                        "--no-warnings", "--socket-timeout", "15", "--retries", "1", "--", url.absoluteString],
            environment: environment, directory: nil)
        return try PreviewParser.video(lines: lines, url: url)
    }
}
