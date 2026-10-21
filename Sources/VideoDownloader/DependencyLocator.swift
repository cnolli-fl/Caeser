import Foundation

enum DependencyLocator {
    static let homebrewDirectories = [
        "/opt/homebrew/bin",       // Homebrew em Apple Silicon
        "/usr/local/bin",          // Homebrew em Intel
    ]

    static var spotifyEnvironment: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Caeser/Tools/spotdl")
    }

    static func locate() -> DependencyInfo {
        DependencyInfo(
            ytDLP: findExecutable(named: "yt-dlp"),
            ffmpeg: findExecutable(named: "ffmpeg"),
            spotDL: findExecutable(named: "spotdl")
        )
    }

    static func findExecutable(named name: String) -> URL? {
        let fileManager = FileManager.default
        let userHome = fileManager.homeDirectoryForCurrentUser
        var directories = homebrewDirectories
        if name == "spotdl" {
            directories = [spotifyEnvironment.appendingPathComponent("bin").path,
                           userHome.appendingPathComponent(".local/bin").path] + directories
        }
        directories += (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init).filter { $0.hasPrefix("/") }
        return directories
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = [spotifyEnvironment.appendingPathComponent("bin").path] + homebrewDirectories
        environment["PATH"] = (extraPaths + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        environment["PYTHONUNBUFFERED"] = "1"
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        return environment
    }
}
