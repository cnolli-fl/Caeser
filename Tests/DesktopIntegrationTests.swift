import Foundation
import Testing
@testable import Caeser

/// Optional integration check against a locally served, generated audio fixture.
/// Unit tests remain offline. See docs/VALIDACAO-2.2.0.md for the invocation.
struct DesktopIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CAESER_INTEGRATION_URL"] != nil), .timeLimit(.minutes(2)))
    @MainActor func realPreviewAndSerialMP3Downloads() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["CAESER_INTEGRATION_TOOLS"]))
        let tools = DependencyInfo(ytDLP: root.appendingPathComponent("yt-dlp"),
                                   ffmpeg: root.appendingPathComponent("ffmpeg"), spotDL: root.appendingPathComponent("spotdl"))
        let base = try #require(environment["CAESER_INTEGRATION_URL"])
        let firstURL = try #require(URL(string: base + "/primeiro.m4a"))
        let preview = try await MediaPreviewService().fetch(url: firstURL, source: .video, tools: tools)
        #expect(!preview.title.isEmpty)
        #expect(preview.originalURL == firstURL)

        let suite = "Caeser-integration-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Caeser-integration-ação-\(UUID())")
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: destination) }
        let model = DownloadViewModel(defaults: defaults, locateTools: { tools })
        model.destinationURL = destination
        model.format = .mp3
        model.urlText = "\(firstURL)\n\(base)/segundo.m4a"
        model.startDownload()
        for _ in 0..<900 {
            if model.queuedItems.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(model.queuedItems.isEmpty)
        #expect(model.history.count == 2)
        for item in model.history {
            #expect(item.status == .completed, "\(item.detail)")
            let file = try #require(item.files.first)
            #expect(file.pathExtension == "mp3")
            #expect((try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 1_000)
        }
        model.stopForQuit()
    }
}
