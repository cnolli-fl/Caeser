import Foundation

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

        args.append(url.absoluteString)
        return args
    }
}

struct DependencyInfo {
    let ytDLP: URL?
    let ffmpeg: URL?

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
