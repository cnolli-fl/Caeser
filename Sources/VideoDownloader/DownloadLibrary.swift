import Foundation

struct DownloadRequest: Codable, Equatable, Sendable {
    let url: URL
    let source: DownloadSource
    let quality: VideoQuality
    let format: VideoFormat
    let destination: URL
    var preview: MediaPreview?

    var duplicateKey: String {
        // YouTube share/watch URLs identify the same video even with tracking parameters.
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = url.host?.lowercased() ?? ""
        let videoID: String? = host == "youtu.be" ? url.lastPathComponent :
            (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].contains(host)
             ? components?.queryItems?.first(where: { $0.name == "v" })?.value : nil)
        let identity = videoID.map { "youtube:\($0)" } ?? url.absoluteString
        return [identity, source.rawValue, format.rawValue,
                format == .mp3 ? "audio" : quality.rawValue,
                destination.standardizedFileURL.path].joined(separator: "\n")
    }
}

enum QueueStatus: String, Codable, Sendable {
    case waiting, downloading, completed, failed, cancelled, interrupted
    var isPending: Bool { self == .waiting || self == .downloading }
    var title: String {
        switch self {
        case .waiting: "Na fila"
        case .downloading: "Baixando"
        case .completed: "Concluído"
        case .failed: "Não concluído"
        case .cancelled: "Cancelado"
        case .interrupted: "Interrompido ao fechar"
        }
    }
    var symbol: String {
        switch self {
        case .waiting: "clock"
        case .downloading: "arrow.down.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle"
        case .cancelled, .interrupted: "pause.circle"
        }
    }
}

struct QueueItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    let request: DownloadRequest
    var title: String
    var status: QueueStatus = .waiting
    var detail = "Na fila"
    var progress: Double?
    var files: [URL] = []
    var createdAt = Date()
    var finishedAt: Date?

    init(request: DownloadRequest) {
        self.request = request
        title = request.preview?.title ?? request.url.absoluteString
    }
}

struct DownloadLibrary: Codable, Sendable {
    var items: [QueueItem] = []
    var isPaused = false
    var pending: [QueueItem] { items.filter { $0.status.isPending } }
    var history: [QueueItem] {
        items.filter { !$0.status.isPending }.sorted { ($0.finishedAt ?? $0.createdAt) > ($1.finishedAt ?? $1.createdAt) }
    }

    mutating func recoverAfterLaunch() {
        for index in items.indices where items[index].status == .downloading {
            items[index].status = .interrupted
            items[index].detail = "O app foi fechado durante o download. Você pode tentar novamente."
            items[index].progress = nil
        }
        // Restoring a session must never start network/file work without a new action.
        if !pending.isEmpty { isPaused = true }
    }

    mutating func trimHistory() {
        let keep = Set(history.prefix(100).map(\.id))
        items.removeAll { !$0.status.isPending && !keep.contains($0.id) }
    }

    mutating func moveWaiting(_ id: UUID, earlier: Bool) {
        let indices = items.indices.filter { items[$0].status == .waiting }
        guard let position = indices.firstIndex(where: { items[$0].id == id }) else { return }
        let next = position + (earlier ? -1 : 1)
        guard indices.indices.contains(next) else { return }
        items.swapAt(indices[position], indices[next])
    }
}

struct DownloadPreferences: Codable, Sendable {
    var quality: VideoQuality = .best
    var format: VideoFormat = .automatic
    var destination: URL
}

enum DownloadBatch {
    static func links(in text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func requests(text: String, source: DownloadSource, quality: VideoQuality,
                         format: VideoFormat, destination: URL, preview: MediaPreview?) throws -> [DownloadRequest] {
        let links = links(in: text)
        guard !links.isEmpty else { throw DownloadInput.InputError.invalidURL }
        guard links.count <= 50 else { throw LibraryError.tooManyLinks }
        // Validate the entire batch before adding anything, so errors never produce a partial batch.
        return try links.map { text in
            let itemSource = links.count == 1 ? source : (DownloadInput.isSpotify(text) ? .spotify : .video)
            let url = try DownloadInput.validatedURL(text, source: itemSource)
            return DownloadRequest(url: url, source: itemSource, quality: quality,
                                   format: itemSource == .spotify ? .mp3 : format, destination: destination,
                                   preview: links.count == 1 && preview?.originalURL == url ? preview : nil)
        }
    }
}

enum LibraryError: LocalizedError {
    case tooManyLinks, queueFull
    var errorDescription: String? {
        switch self {
        case .tooManyLinks: "Cole até 50 links por vez."
        case .queueFull: "A fila já tem 100 itens. Espere alguns terminarem antes de adicionar mais."
        }
    }
}
