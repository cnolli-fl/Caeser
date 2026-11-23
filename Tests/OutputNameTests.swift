import Foundation
import Testing
@testable import Caeser

struct OutputNameTests {
    @Test func namesStayLiteralAndPersistWithQueue() throws {
        let name = try OutputName.validated("  Minha música 100%.MP3 ")
        #expect(name == "Minha música 100%")
        let request = DownloadRequest(url: URL(string: "https://youtu.be/example")!, source: .video,
                                      quality: .best, format: .mp3,
                                      destination: URL(fileURLWithPath: "/tmp"), fileName: name)
        let restored = try JSONDecoder().decode(DownloadRequest.self, from: JSONEncoder().encode(request))
        #expect(restored.fileName == name)
        let args = DownloadOptions(url: request.url, destination: request.destination,
                                   quality: .best, format: .mp3, fileName: name).arguments
        #expect(args[args.firstIndex(of: "-o")! + 1] == "Minha música 100%%.%(ext)s")
        var other = request
        other.fileName = "Outra música"
        #expect(other.duplicateKey != request.duplicateKey)
        let old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any]
        let legacy = old.filter { $0.key != "fileName" }
        #expect(try JSONDecoder().decode(DownloadRequest.self, from: JSONSerialization.data(withJSONObject: legacy)).fileName == nil)
    }

    @Test func invalidNamesAndCollectionsAreRejected() throws {
        #expect(try OutputName.validated(" ") == nil)
        for name in ["../arquivo", "CON", "aux.mp3", "x/{title}", "x\\y", ".", ".mp4"] {
            #expect(throws: (any Error).self) { try OutputName.validated(name) }
        }
        #expect(throws: (any Error).self) {
            try DownloadBatch.requests(text: "https://youtu.be/a https://youtu.be/b", source: .video,
                                       quality: .best, format: .mp4, destination: URL(fileURLWithPath: "/tmp"),
                                       preview: nil, fileName: "Nome único")
        }
        let spotify = SpotifyDownloadOptions(url: URL(string: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT")!,
                                             ffmpeg: URL(fileURLWithPath: "/ffmpeg"),
                                             errorReport: URL(fileURLWithPath: "/report"), fileName: "Minha música")
        #expect(spotify.arguments[spotify.arguments.firstIndex(of: "--output")! + 1] == "Minha música.{output-ext}")
    }
}
