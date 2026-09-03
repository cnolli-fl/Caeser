import Foundation

enum DependencyLocator {
    private static let homebrewDirectories = [
        "/opt/homebrew/bin",       // Homebrew em Apple Silicon
        "/usr/local/bin",          // Homebrew em Intel
        "/home/linuxbrew/.linuxbrew/bin"
    ]

    static func locate() -> DependencyInfo {
        DependencyInfo(
            ytDLP: findExecutable(named: "yt-dlp"),
            ffmpeg: findExecutable(named: "ffmpeg")
        )
    }

    static func findExecutable(named name: String) -> URL? {
        let fileManager = FileManager.default
        return homebrewDirectories
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
