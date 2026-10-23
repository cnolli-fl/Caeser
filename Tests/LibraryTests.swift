import Foundation
import Testing
@testable import Caeser

private let videoLink = URL(string: "https://www.youtube.com/watch?v=example")!
private let spotifyLink = URL(string: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT")!

struct PreviewTests {
    @Test func videoMetadataHandlesMissingArtworkAndUnicode() throws {
        let preview = try PreviewParser.video(lines: ["warning", #"{"title":"Canção — ao vivo","channel":"João","duration":3723,"thumbnail":"http://unsafe.test/image"}"#], url: videoLink)
        #expect(preview.title == "Canção — ao vivo")
        #expect(preview.durationText == "1:02:03")
        #expect(preview.artworkURL == nil)
        #expect(MediaPreview.durationText(.infinity) == nil)
        #expect(MediaPreview.durationText(-1) == nil)
    }

    @Test func spotifyPreviewPinsTheSameMatchInDownloadArguments() throws {
        let data = Data(#"[{"name":"Canção","artists":["Artista"],"duration":213,"download_url":"https://www.youtube.com/watch?v=chosen"}]"#.utf8)
        let preview = try PreviewParser.spotify(data: data, url: spotifyLink)
        #expect(preview.title == "Canção")
        #expect(preview.durationText == "3:33")
        let options = SpotifyDownloadOptions(url: spotifyLink, ffmpeg: URL(fileURLWithPath: "/ffmpeg"),
                                             errorReport: URL(fileURLWithPath: "/report"), matchedURL: preview.matchedURL)
        #expect(options.arguments[1] == "https://www.youtube.com/watch?v=chosen|\(spotifyLink.absoluteString)")
        #expect(options.arguments[options.arguments.firstIndex(of: "--bitrate")! + 1] == "0")
    }

    @Test func collectionDoesNotPretendOneMatchRepresentsAllSongs() throws {
        let data = Data(#"[{"name":"A","artists":["Artista"],"duration":12,"list_name":"Minha playlist","download_url":"https://youtube.com/watch?v=a"},{"name":"B","artists":["Artista"],"duration":23}]"#.utf8)
        let preview = try PreviewParser.spotify(data: data, url: URL(string: "https://open.spotify.com/playlist/4cOdK2wGLETKBW3PvgPWqT")!)
        #expect(preview.title == "Minha playlist")
        #expect(preview.trackCount == 2)
        #expect(preview.duration == 35)
        #expect(preview.matchedURL == nil)
    }

    @Test func malformedAndUnsafePreviewMetadataIsRejected() {
        #expect(throws: (any Error).self) { try PreviewParser.spotify(data: Data("[null]".utf8), url: spotifyLink) }
        #expect(throws: (any Error).self) { try PreviewParser.video(lines: ["not json"], url: videoLink) }
        #expect(PreviewParser.youtubeURL("https://youtube.com.evil.test/watch?v=a") == nil)
        #expect(PreviewParser.youtubeURL("file:///tmp/payload") == nil)
        #expect(PreviewParser.youtubeURL("https://user:pass@youtube.com/watch?v=a") == nil)
    }
}

struct ReleaseUpdateTests {
    static func release(_ tag: String, prerelease: Bool = false, draft: Bool = false,
                        assetName: String? = nil, host: String = "github.com") -> [String: Any] {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = assetName ?? "Caeser-\(version)-macOS-AppleSilicon.dmg"
        return ["tag_name": tag, "draft": draft, "prerelease": prerelease,
                "html_url": "https://\(host)/cnolli-fl/Caeser/releases/tag/\(tag)",
                "assets": [["name": name, "size": 100, "state": "uploaded",
                            "browser_download_url": "https://\(host)/cnolli-fl/Caeser/releases/download/\(tag)/\(name)"]]]
    }
    @Test func selectsNewestMacInstallerRegardlessOfWindowsOrSourceReleaseOrder() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            Self.release("windows-v99.0.0"), Self.release("fontes-terceiros"),
            Self.release("v2.9.0"), Self.release("v2.10.0"), Self.release("v3.0.0", prerelease: true),
            Self.release("v4.0.0", draft: true), Self.release("v5.0.0", assetName: "source.zip"),
            Self.release("v6.0.0", host: "github.com.evil.test")])
        #expect(try ReleaseParser.available(data: data, currentVersion: "2.2.0")?.version == "2.10.0")
        #expect(try ReleaseParser.available(data: data, currentVersion: "2.10.0") == nil)
        #expect(try ReleaseParser.available(data: data, currentVersion: "9.0.0") == nil)
        #expect(ReleaseVersion("v2.2.0-beta.1") == nil)
        #expect(ReleaseVersion("v2.2") == nil)
    }

    @Test @MainActor func updateFailuresAreNonBlockingAndManualCheckCanRetry() async throws {
        let model = ReleaseUpdateModel(currentVersion: "2.2.0", load: { throw URLError(.notConnectedToInternet) })
        await model.check()
        #expect(model.available == nil)
        #expect(!model.isChecking)
        #expect(!model.showsDetails)
        await model.check(manual: true)
        #expect(model.showsDetails)
        #expect(model.message?.contains("conexão") == true)
    }

    @Test @MainActor func automaticCheckDoesNotPresentAModalForANewRelease() async throws {
        let data = try JSONSerialization.data(withJSONObject: [Self.release("v2.3.0")])
        let model = ReleaseUpdateModel(currentVersion: "2.2.0", load: { data })
        await model.check()
        #expect(model.available?.version == "2.3.0")
        #expect(!model.showsDetails)
    }
}

struct DownloadLibraryTests {
    @Test func validatesTheWholeBatchAndDetectsMixedSources() throws {
        let destination = URL(fileURLWithPath: "/tmp/test")
        let text = "\(videoLink)\n\(spotifyLink)"
        let requests = try DownloadBatch.requests(text: text, source: .video, quality: .p1080,
                                                 format: .mp4, destination: destination, preview: nil)
        #expect(requests.map(\.source) == [.video, .spotify])
        #expect(requests.map(\.format) == [.mp4, .mp3])
        #expect(throws: (any Error).self) {
            try DownloadBatch.requests(text: text + "\n--help", source: .video, quality: .best,
                                       format: .mp3, destination: destination, preview: nil)
        }
    }

    @Test func crashRecoveryNeverAutoRestartsInterruptedDownloads() throws {
        let request = DownloadRequest(url: videoLink, source: .video, quality: .best, format: .mp3,
                                      destination: URL(fileURLWithPath: "/tmp"))
        var active = QueueItem(request: request)
        active.status = .downloading
        var library = DownloadLibrary(items: [active, QueueItem(request: request)])
        library = try JSONDecoder().decode(DownloadLibrary.self, from: JSONEncoder().encode(library))
        library.recoverAfterLaunch()
        #expect(library.items.map(\.status) == [.interrupted, .waiting])
        #expect(library.isPaused)
    }

    @Test func reorderingOnlyMovesWaitingItemsAndHistoryIsBounded() {
        let request = DownloadRequest(url: videoLink, source: .video, quality: .best, format: .mp3,
                                      destination: URL(fileURLWithPath: "/tmp"))
        var active = QueueItem(request: request); active.status = .downloading
        let first = QueueItem(request: request), second = QueueItem(request: request)
        var library = DownloadLibrary(items: [active, first, second])
        library.moveWaiting(second.id, earlier: true)
        #expect(library.items.map(\.id) == [active.id, second.id, first.id])
        for _ in 0..<110 {
            var done = QueueItem(request: request); done.status = .completed
            library.items.append(done)
        }
        library.trimHistory()
        #expect(library.history.count == 100)
        #expect(library.pending.count == 3)
    }
}

private final class FakeDownloadProcess: DownloadRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var onLine: (@Sendable (String) -> Void)?
    private var onFinish: (@Sendable (ProcessOutcome) -> Void)?
    private var capturedArguments: [String] = []
    private var capturedDirectory: URL?
    var arguments: [String] { lock.withLock { capturedArguments } }
    var directory: URL? { lock.withLock { capturedDirectory } }
    func start(executableURL: URL, arguments: [String], environment: [String: String], currentDirectoryURL: URL?,
               output: @escaping @Sendable (String) -> Void, completion: @escaping @Sendable (ProcessOutcome) -> Void) throws {
        lock.withLock { onLine = output; onFinish = completion; capturedArguments = arguments; capturedDirectory = currentDirectoryURL }
    }
    func emit(_ line: String) { lock.withLock { onLine }?(line) }
    func finish(_ code: Int32) { lock.withLock { onFinish }?(.exited(code)) }
    func cancel() { finish(15) }
}

@MainActor
private final class LibraryHarness {
    let suite = "Caeser-tests-\(UUID())"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Caeser-tests-\(UUID())")
    var processes: [FakeDownloadProcess] = []
    var defaults: UserDefaults { UserDefaults(suiteName: suite)! }
    func model() -> DownloadViewModel {
        DownloadViewModel(defaults: defaults, locateTools: {
            DependencyInfo(ytDLP: URL(fileURLWithPath: "/fake/yt-dlp"), ffmpeg: URL(fileURLWithPath: "/fake/ffmpeg"),
                           spotDL: URL(fileURLWithPath: "/fake/spotdl"))
        }, makeProcess: { [self] in
            let process = FakeDownloadProcess(); processes.append(process); return process
        }, previewLoader: { _, _, _ in throw CancellationError() })
    }
    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
struct QueueExecutionTests {
    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func serialQueuePreservesSettingsAndContinuesAfterFailure() async throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let model = h.model()
        model.destinationURL = h.directory.appendingPathComponent("primeira")
        model.format = .mp3
        model.urlText = videoLink.absoluteString
        model.startDownload()
        model.destinationURL = h.directory.appendingPathComponent("segunda")
        model.format = .mp4
        model.urlText = "https://youtube.com/watch?v=second"
        model.startDownload()
        #expect(h.processes.count == 1)
        #expect(model.queuedItems.count == 2)
        #expect(h.processes[0].directory?.lastPathComponent == "primeira")
        #expect(h.processes[0].arguments.contains("--audio-quality"))
        h.processes[0].finish(1)
        try await eventually { h.processes.count == 2 }
        #expect(model.history.first?.status == .failed)
        #expect(h.processes[1].directory?.lastPathComponent == "segunda")
        #expect(!h.processes[1].arguments.contains("--audio-quality"))
        h.processes[0].emit("download:99%|1|1|stale|0") // A late old process cannot update the next one.
        h.processes[1].emit(#"CAESER_TITLE:"Segundo vídeo""#)
        h.processes[1].finish(0)
        try await eventually { model.queuedItems.isEmpty }
        #expect(model.history.contains { $0.title == "Segundo vídeo" && $0.status == .completed })
    }

    @Test func pauseAllowsActiveDownloadToFinishAndResumeStartsNext() async throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let model = h.model(); model.destinationURL = h.directory
        model.urlText = "https://youtube.com/watch?v=first\nhttps://youtube.com/watch?v=second"
        model.startDownload()
        model.toggleQueuePause()
        h.processes[0].finish(0)
        try await eventually { !model.isDownloading }
        #expect(h.processes.count == 1)
        #expect(model.queuedItems.count == 1)
        model.toggleQueuePause()
        #expect(h.processes.count == 2)
        model.cancelDownload()
        try await eventually { model.queuedItems.isEmpty }
        #expect(model.history.first?.status == .cancelled)
    }

    @Test func removesWaitingItemsWithoutCancellingTheActiveOneAndSuppressesDuplicates() async throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let model = h.model(); model.destinationURL = h.directory
        model.urlText = "https://youtube.com/watch?v=first\nhttps://youtu.be/first\nhttps://youtube.com/watch?v=second"
        model.startDownload()
        #expect(model.queuedItems.count == 2)
        #expect(model.inputMessage?.contains("1 link") == true)
        model.removeFromQueue(try #require(model.queuedItems.last?.id))
        #expect(model.queuedItems.count == 1)
        #expect(model.isDownloading)
        model.cancelDownload()
        try await eventually { !model.isDownloading }
    }

    @Test func restoresHistoryAndPreferencesWithoutStartingProcessesOrDeletingFiles() async throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let model = h.model(); model.destinationURL = h.directory; model.format = .mp3; model.quality = .p720
        model.urlText = videoLink.absoluteString; model.startDownload()
        let file = h.directory.appendingPathComponent("canção.mp3")
        try Data("test".utf8).write(to: file)
        let pathJSON = String(decoding: try JSONEncoder().encode(file.path), as: UTF8.self)
        h.processes[0].emit("CAESER_FILE:\(pathJSON)")
        h.processes[0].finish(0)
        try await eventually { model.history.count == 1 }
        model.source = .spotify; model.destinationURL = h.directory.appendingPathComponent("spotify")
        model.source = .video
        #expect(model.destinationURL == h.directory)
        #expect(model.format == .mp3)
        let reopened = h.model()
        #expect(reopened.history.count == 1)
        #expect(reopened.history[0].files == [file])
        #expect(reopened.quality == .p720)
        #expect(h.processes.count == 1)
        reopened.urlText = videoLink.absoluteString; reopened.startDownload()
        #expect(reopened.queuedItems.isEmpty)
        reopened.clearHistory()
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func newDownloadResumesRestoredQueueWithOneAction() async throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let request = DownloadRequest(url: videoLink, source: .video, quality: .best, format: .mp3,
                                      destination: h.directory)
        let library = DownloadLibrary(items: [QueueItem(request: request)])
        h.defaults.set(try JSONEncoder().encode(library), forKey: "downloadLibrary.v1")
        let model = h.model()
        #expect(model.isQueuePaused)
        #expect(h.processes.isEmpty)
        model.destinationURL = h.directory
        model.urlText = "https://youtube.com/watch?v=new-download"
        model.startDownload()
        #expect(!model.isQueuePaused)
        #expect(model.isDownloading)
        #expect(h.processes.count == 1)
        #expect(model.queuedItems.count == 2)
        h.processes[0].finish(0)
        try await eventually { h.processes.count == 2 }
        h.processes[1].finish(0)
        try await eventually { model.queuedItems.isEmpty }
    }

    @Test func invalidOrDuplicateInputDoesNotResumePausedQueue() throws {
        let h = LibraryHarness(); defer { h.cleanup() }
        let request = DownloadRequest(url: videoLink, source: .video, quality: .best, format: .mp3,
                                      destination: h.directory)
        h.defaults.set(try JSONEncoder().encode(DownloadLibrary(items: [QueueItem(request: request)])),
                       forKey: "downloadLibrary.v1")
        let model = h.model()
        model.destinationURL = h.directory; model.format = .mp3
        model.urlText = "--invalid"; model.startDownload()
        #expect(model.isQueuePaused)
        model.urlText = videoLink.absoluteString; model.startDownload()
        #expect(model.isQueuePaused)
        #expect(h.processes.isEmpty)
        #expect(model.queuedItems.count == 1)
    }

    @Test func stalePreviewCannotReplaceTheCurrentLink() async throws {
        let suite = "Caeser-preview-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = DownloadViewModel(defaults: defaults, previewLoader: { url, _, _ in
            // Deliberately ignore cancellation to simulate a slow callback arriving late.
            try? await Task.sleep(for: .milliseconds(url.absoluteString.contains("first") ? 100 : 10))
            return MediaPreview(originalURL: url, title: url.lastPathComponent, creator: "", artworkURL: nil, duration: nil)
        })
        model.urlText = "https://example.test/first"; model.schedulePreview(immediate: true)
        await Task.yield()
        model.urlText = "https://example.test/second"; model.schedulePreview(immediate: true)
        try await eventually { model.preview != nil }
        #expect(model.preview?.title == "second")
        model.urlText = ""
        #expect(model.preview == nil)
        #expect(!model.isLoadingPreview)
    }
}
