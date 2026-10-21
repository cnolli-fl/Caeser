import Foundation

enum DownloadSource: String, CaseIterable, Identifiable, Sendable {
    case video = "YouTube"
    case spotify = "Spotify"

    var id: Self { self }
    var symbol: String { self == .spotify ? "music.note" : "play.rectangle" }
}

enum DownloadInput {
    static func isSpotify(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.lowercased().hasPrefix("spotify:")
            || URL(string: value)?.host?.lowercased() == "open.spotify.com"
    }

    static func validatedURL(_ text: String, source: DownloadSource) throws -> URL {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("spotify:") {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 3 else { throw InputError.invalidSpotify }
            value = "https://open.spotify.com/\(parts[1])/\(parts[2])"
        }
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { throw InputError.invalidURL }
        guard source == .spotify else {
            guard !isSpotify(value) else { throw InputError.selectSpotify }
            return url
        }
        guard host.lowercased() == "open.spotify.com" else { throw InputError.invalidSpotify }
        let parts = url.pathComponents.filter { $0 != "/" }.filter { !$0.hasPrefix("intl-") }
        guard parts.count == 2, ["track", "album", "playlist"].contains(parts[0]),
              parts[1].count == 22,
              parts[1].unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII })
        else { throw InputError.invalidSpotify }
        return URL(string: "https://open.spotify.com/\(parts[0])/\(parts[1])")!
    }

    enum InputError: LocalizedError {
        case invalidURL, invalidSpotify, selectSpotify
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Cole um link completo começando com https://."
            case .invalidSpotify: return "Cole um link público de música, álbum ou playlist de open.spotify.com. Links privados e links curtos não são suportados."
            case .selectSpotify: return "Selecione Spotify para buscar esta música no YouTube."
            }
        }
    }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case best = "Melhor disponível"
    case p2160 = "Até 4K (2160p)"
    case p1440 = "Até 1440p"
    case p1080 = "Até 1080p"
    case p720 = "Até 720p"
    case p480 = "Até 480p"

    var id: String { rawValue }

    var maximumHeight: Int? {
        switch self {
        case .best: return nil
        case .p2160: return 2160
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        }
    }
}

enum VideoFormat: String, CaseIterable, Identifiable {
    case automatic = "Automático"
    case mp4 = "MP4"
    case webm = "WebM"
    case mp3 = "MP3"

    var id: String { rawValue }
}

struct DownloadOptions {
    let url: URL
    let destination: URL
    let quality: VideoQuality
    let format: VideoFormat

    var arguments: [String] {
        var args = [
            "--ignore-config",
            "--newline",
            "--progress",
            "--no-playlist",
            "--paths", destination.path,
            "-o", "%(title)s.%(ext)s",
            "--progress-template",
            "download:%(progress._percent_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s|%(progress._eta)s"
        ]

        let height = quality.maximumHeight.map(String.init)
        let formatSelector: String

        switch (format, height) {
        case (.mp3, _):
            formatSelector = "bestaudio/best"
        case (.automatic, nil):
            formatSelector = "bv*+ba/b"
        case (.automatic, let height?):
            formatSelector = "bv*[height<=\(height)]+ba/b[height<=\(height)]"
        case (.mp4, nil):
            formatSelector = "bv*[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b"
        case (.mp4, let height?):
            formatSelector = "bv*[height<=\(height)][ext=mp4][vcodec^=avc1]+ba[ext=m4a]/bv*[height<=\(height)][ext=mp4]+ba[ext=m4a]/b[height<=\(height)][ext=mp4]/b[height<=\(height)]"
        case (.webm, nil):
            formatSelector = "bv*[ext=webm]+ba[ext=webm]/bv*+ba/b"
        case (.webm, let height?):
            formatSelector = "bv*[height<=\(height)][ext=webm]+ba[ext=webm]/bv*[height<=\(height)]+ba/b[height<=\(height)]"
        }

        args += ["-f", formatSelector]

        switch format {
        case .automatic:
            break
        case .mp4:
            args += ["--merge-output-format", "mp4"]
        case .webm:
            args += ["--merge-output-format", "webm"]
        case .mp3:
            args += [
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0"
            ]
        }

        args += ["--", url.absoluteString]
        return args
    }
}

struct SpotifyDownloadOptions {
    let url: URL
    let ffmpeg: URL
    let errorReport: URL

    var arguments: [String] {
        // Resolve the template in the subprocess working directory. A folder named
        // with braces or percent signs must not become part of the template.
        return [
            "download", url.absoluteString,
            // Prefer the regular YouTube provider, which is more reliable without login.
            "--audio", "youtube", "youtube-music",
            "--format", "mp3", "--bitrate", "0",
            "--ffmpeg", ffmpeg.path,
            "--output", "{artists} - {title} [{track-id}].{output-ext}",
            "--threads", "1", "--overwrite", "skip",
            "--simple-tui", "--headless", "--max-retries", "2",
            "--log-level", "INFO", "--log-format", "SPOTDL|%(levelname)s|%(message)s",
            "--save-errors", errorReport.path,
            "--lyrics"
        ]
    }
}

struct DependencyInfo {
    let ytDLP: URL?
    let ffmpeg: URL?
    let spotDL: URL?

    func isReady(for source: DownloadSource) -> Bool {
        ffmpeg != nil && (source == .spotify ? spotDL != nil : ytDLP != nil)
    }

    func missing(for source: DownloadSource) -> [String] {
        var names: [String] = []
        if source == .spotify, spotDL == nil { names.append("spotDL") }
        if source == .video, ytDLP == nil { names.append("yt-dlp") }
        if ffmpeg == nil { names.append("FFmpeg") }
        return names
    }

    var isReady: Bool {
        ytDLP != nil && ffmpeg != nil
    }

    var message: String {
        switch (ytDLP != nil, ffmpeg != nil) {
        case (true, true): return "yt-dlp e FFmpeg encontrados"
        case (false, true): return "yt-dlp não foi encontrado"
        case (true, false): return "FFmpeg não foi encontrado"
        case (false, false): return "yt-dlp e FFmpeg não foram encontrados"
        }
    }
}

enum ProcessOutcome: Sendable {
    case exited(Int32)
    case failed(String)
}

struct SpotifyLogEvent: Equatable {
    let message: String
    let isError: Bool
    let completed: Int?
    let total: Int?

    init(line: String) {
        let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        isError = parts.count == 3 && parts[0] == "SPOTDL" && ["ERROR", "CRITICAL"].contains(String(parts[1]))
        message = parts.count == 3 && parts[0] == "SPOTDL" ? String(parts[2]) : line
        let expression = try? NSRegularExpression(pattern: #"^(\d+)/(\d+) complete$"#)
        if let match = expression?.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let completedRange = Range(match.range(at: 1), in: message),
           let totalRange = Range(match.range(at: 2), in: message) {
            completed = Int(message[completedRange])
            total = Int(message[totalRange])
        } else {
            completed = nil
            total = nil
        }
    }
}
