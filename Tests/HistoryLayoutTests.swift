import AppKit
import SwiftUI
import Testing
@testable import Caeser

@Suite(.serialized)
struct HistoryLayoutTests {
    @Test @MainActor func historyHasBoundedProportions() throws {
        for count in [0, 1, 12, 100] {
            let suite = "Caeser-UITests-history-\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var library = DownloadLibrary()
            for index in 0..<count {
                let request = DownloadRequest(url: URL(string: "https://youtube.com/watch?v=fixture\(index)")!, source: .video,
                    quality: .best, format: .mp3, destination: FileManager.default.temporaryDirectory)
                var item = QueueItem(request: request)
                item.title = String(repeating: "Um título longo ", count: 20)
                item.status = .failed
                item.detail = String(repeating: "Erro longo. ", count: 40)
                library.items.append(item)
            }
            defaults.set(try JSONEncoder().encode(library), forKey: "downloadLibrary.v1")
            let model = DownloadViewModel(defaults: defaults)
            let view = NSHostingView(rootView: DownloadHistoryView(model: model))
            let size = view.fittingSize
            #expect(size.width == 600)
            #expect(size.height >= 240 && size.height <= 520)
            #expect(model.history.count == count)
        }
    }
}
