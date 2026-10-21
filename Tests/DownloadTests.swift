import AppKit
import Foundation
import Testing
@testable import Caeser

struct BrandArtworkTests {
    @Test @MainActor func brandMarksHavePixelMatchedTransparentPNGsAtEveryScale() throws {
        for source in DownloadSource.allCases {
            for scale in 1...3 {
                let image = try #require(SourceBrandIcon.image(for: source, scale: scale))
                let bitmap = NSBitmapImageRep(cgImage: image)
                #expect(bitmap.pixelsWide == 36 * scale)
                #expect(bitmap.pixelsHigh == 24 * scale)
                #expect(bitmap.hasAlpha)
                #expect(try #require(bitmap.colorAt(x: 0, y: 0)).alphaComponent == 0)

                var transparentSamples = 0, whiteSamples = 0, antialiasedSamples = 0
                var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                        if color.alphaComponent == 0 { transparentSamples += 1 }
                        if color.alphaComponent > 0 && color.alphaComponent < 1 { antialiasedSamples += 1 }
                        if color.alphaComponent > 0.99 && color.redComponent > 0.99
                            && color.greenComponent > 0.99 && color.blueComponent > 0.99 {
                            whiteSamples += 1
                        }
                        if color.alphaComponent > 0.5 {
                            minX = min(minX, x); minY = min(minY, y)
                            maxX = max(maxX, x); maxY = max(maxY, y)
                        }
                    }
                }
                #expect(transparentSamples > 0)
                #expect(whiteSamples > 0)
                #expect(antialiasedSamples > 0)
                if source == .spotify {
                    // A circular mark must not become an ellipse when fitting the slot.
                    #expect(abs((maxX - minX) - (maxY - minY)) <= 1)
                }
            }
        }
    }

    @Test @MainActor func brandMarksChooseTheNativeRetinaScale() {
        #expect(SourceBrandIcon.assetScale(for: 1) == 1)
        #expect(SourceBrandIcon.assetScale(for: 2) == 2)
        #expect(SourceBrandIcon.assetScale(for: 3) == 3)
        #expect(SourceBrandIcon.assetScale(for: 1.5) == 2)
        #expect(SourceBrandIcon.assetScale(for: 0) == 1)
        #expect(SourceBrandIcon.assetScale(for: 4) == 3)
    }
}

struct DownloadInputTests {
    private let trackID = "4cOdK2wGLETKBW3PvgPWqT"

    @Test func normalizesSpotifySharingURL() throws {
        let url = try DownloadInput.validatedURL(
            " https://open.spotify.com/intl-pt/track/\(trackID)?si=share \n", source: .spotify
        )
        #expect(url.absoluteString == "https://open.spotify.com/track/\(trackID)")
    }

    @Test func acceptsSpotifyURI() throws {
        let url = try DownloadInput.validatedURL("spotify:track:\(trackID)", source: .spotify)
        #expect(url.path == "/track/\(trackID)")
    }

    @Test(arguments: ["track", "album", "playlist"])
    func acceptsPublicCollectionTypes(_ type: String) throws {
        #expect(try DownloadInput.validatedURL("https://open.spotify.com/\(type)/\(trackID)", source: .spotify).host == "open.spotify.com")
    }

    @Test(arguments: [
        "https://open.spotify.com.evil.test/track/4cOdK2wGLETKBW3PvgPWqT",
        "https://open.spotify.com/artist/4cOdK2wGLETKBW3PvgPWqT",
        "https://open.spotify.com/track/invalid",
        "https://spotify.link/short",
        "https://user:password@open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT"
    ])
    func rejectsUnsupportedSpotifyLinks(_ text: String) {
        #expect(throws: (any Error).self) { try DownloadInput.validatedURL(text, source: .spotify) }
    }

    @Test(arguments: ["", "https://", "file:///tmp/track", "--help", "just text"])
    func rejectsInvalidVideoInput(_ text: String) {
        #expect(throws: (any Error).self) { try DownloadInput.validatedURL(text, source: .video) }
    }

    @Test func spotifyDoesNotFallThroughToYTDLP() {
        #expect(throws: (any Error).self) {
            try DownloadInput.validatedURL("https://open.spotify.com/track/\(trackID)", source: .video)
        }
        #expect(!DownloadInput.isSpotify("https://open.spotify.com.evil.test/track/\(trackID)"))
    }
}

struct DownloadConfigurationTests {
    @Test func mp3IgnoresVideoResolutionAndUsesBestAudio() {
        let options = DownloadOptions(
            url: URL(string: "https://youtube.com/watch?v=sample")!,
            destination: URL(fileURLWithPath: "/tmp/My Music"), quality: .p480, format: .mp3
        )
        let arguments = options.arguments
        #expect(arguments.contains("bestaudio/best"))
        #expect(!arguments.joined().contains("height"))
        #expect(arguments.contains("--ignore-config"))
        #expect(arguments.suffix(2) == ["--", options.url.absoluteString])
        #expect(arguments[arguments.firstIndex(of: "--audio-quality")! + 1] == "0")
        #expect(arguments[arguments.firstIndex(of: "--paths")! + 1] == "/tmp/My Music")
    }

    @Test func spotifyUsesYouTubeAndNeverRequestsUserAuthentication() {
        let options = SpotifyDownloadOptions(
            url: URL(string: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT")!,
            ffmpeg: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            errorReport: URL(fileURLWithPath: "/tmp/report.txt")
        )
        let args = options.arguments
        #expect(args.contains("youtube-music") && args.contains("youtube"))
        #expect(!args.contains("--user-auth"))
        #expect(args[args.firstIndex(of: "--bitrate")! + 1] == "0")
        #expect(args.contains("--save-errors"))
        #expect(args[args.firstIndex(of: "--overwrite")! + 1] == "skip")
    }

    @Test func spotifyDependencyDoesNotBlockVideoDownloads() {
        let info = DependencyInfo(ytDLP: URL(fileURLWithPath: "/yt-dlp"), ffmpeg: URL(fileURLWithPath: "/ffmpeg"), spotDL: nil)
        #expect(info.isReady(for: .video))
        #expect(!info.isReady(for: .spotify))
        #expect(info.missing(for: .spotify) == ["spotDL"])
    }

    @Test func recognizesErrorsAndCollectionProgress() {
        let progress = SpotifyLogEvent(line: "SPOTDL|INFO|3/10 complete")
        #expect(progress.completed == 3 && progress.total == 10)
        #expect(!progress.isError)
        #expect(SpotifyLogEvent(line: "SPOTDL|ERROR|No match|more detail").isError)
        #expect(SpotifyLogEvent(line: "SPOTDL|ERROR|No match|more detail").message == "No match|more detail")
        #expect(SpotifyLogEvent(line: "A song named 3/10 complete").completed == nil)
    }
}

struct DownloadProcessTests {
    @Test(.timeLimit(.minutes(1))) func drainsFinalErrorAndPreservesSplitUTF8() async throws {
        let collector = LineCollector()
        let outcome: ProcessOutcome = try await withCheckedThrowingContinuation { continuation in
            let process = DownloadProcess()
            do { try process.start(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "printf '\\303'; sleep 0.02; printf '\\247\\303\\243o\\rfinal-error' >&2; exit 7"],
                environment: ProcessInfo.processInfo.environment,
                output: { collector.append($0) }, completion: { continuation.resume(returning: $0) }
            ) } catch { continuation.resume(throwing: error) }
        }
        #expect(collector.lines == ["ção", "final-error"])
        if case .exited(let status) = outcome { #expect(status == 7) }
        else { Issue.record("Expected exit status 7") }
    }

    @Test(.timeLimit(.minutes(1))) func canCancelImmediatelyAfterStarting() async throws {
        let outcome: ProcessOutcome = try await withCheckedThrowingContinuation { continuation in
            let process = DownloadProcess()
            do { try process.start(
                executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["20"],
                environment: ProcessInfo.processInfo.environment,
                output: { _ in }, completion: { continuation.resume(returning: $0) }
            )
            process.cancel()
            } catch { continuation.resume(throwing: error) }
        }
        if case .exited(let status) = outcome { #expect(status != 0) }
        else { Issue.record("Expected cancellation to terminate the process") }
    }

    @Test(.timeLimit(.minutes(1))) func cancellationAlsoStopsChildProcesses() async throws {
        let process = DownloadProcess()
        let started = Date()
        let outcome: ProcessOutcome = try await withCheckedThrowingContinuation { continuation in
            do {
                try process.start(
                    executableURL: URL(fileURLWithPath: "/bin/sh"),
                    arguments: ["-c", "sleep 20 & printf 'ready\\n'; wait"],
                    environment: ProcessInfo.processInfo.environment,
                    output: { line in if line == "ready" { process.cancel() } },
                    completion: { continuation.resume(returning: $0) }
                )
            } catch { continuation.resume(throwing: error) }
        }
        #expect(Date().timeIntervalSince(started) < 5)
        if case .exited(let status) = outcome { #expect(status != 0) }
        else { Issue.record("Expected cancellation to terminate the process tree") }
    }
}

private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return storage }
    func append(_ line: String) { lock.lock(); defer { lock.unlock() }; storage.append(line) }
}
