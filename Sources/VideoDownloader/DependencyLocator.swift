import Foundation

enum DependencyLocator {
    /// Packaging places standalone tools here; never depend on the developer's PATH.
    static var bundledToolsDirectory: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let directory = resources.appendingPathComponent("Tools", isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.path) ? directory : nil
    }

    static var isBundledDistribution: Bool { bundledToolsDirectory != nil }

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

    static func findExecutable(
        named name: String,
        bundledDirectory: URL? = bundledToolsDirectory,
        fallbackDirectories: [String]? = nil
    ) -> URL? {
        let fileManager = FileManager.default
        // An incomplete standalone package must report the missing tool, not
        // silently succeed only on machines that happen to have Homebrew.
        if let bundledDirectory {
            let executable = bundledDirectory.appendingPathComponent(name)
            return fileManager.isExecutableFile(atPath: executable.path) ? executable : nil
        }
        if let fallbackDirectories {
            return fallbackDirectories.map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
                .first { fileManager.isExecutableFile(atPath: $0.path) }
        }
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

    static func processEnvironment(
        bundledDirectory: URL? = bundledToolsDirectory,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = baseEnvironment
        if let bundledDirectory {
            environment["PATH"] = bundledDirectory.path + ":/usr/bin:/bin:/usr/sbin:/sbin"
            // Prevent shell/virtualenv settings from breaking embedded Python tools.
            for key in ["PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV", "SSL_CERT_FILE", "REQUESTS_CA_BUNDLE"] {
                environment.removeValue(forKey: key)
            }
            for key in environment.keys.filter({ $0.hasPrefix("DYLD_") }) {
                environment.removeValue(forKey: key)
            }
        } else {
            let extraPaths = [spotifyEnvironment.appendingPathComponent("bin").path] + homebrewDirectories
            environment["PATH"] = (extraPaths + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        }
        environment["DENO_NO_UPDATE_CHECK"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        return environment
    }
}
