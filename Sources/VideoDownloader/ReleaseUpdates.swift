import Foundation
import SwiftUI

struct ReleaseVersion: Comparable, Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]) else { return nil }
        self.major = major; self.minor = minor; self.patch = patch
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

struct ReleaseUpdate: Equatable, Sendable {
    let version: String
    let pageURL: URL
    let downloadURL: URL
}

enum ReleaseParser {
    struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }
    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
        let state: String
    }

    static func available(data: Data, currentVersion: String) throws -> ReleaseUpdate? {
        guard let current = ReleaseVersion(currentVersion) else { return nil }
        let releases = try JSONDecoder().decode([Release].self, from: data)
        return releases.compactMap { release -> (ReleaseVersion, ReleaseUpdate)? in
            guard !release.draft, !release.prerelease, release.tag_name.hasPrefix("v"),
                  let version = ReleaseVersion(release.tag_name), version > current else { return nil }
            let name = String(release.tag_name.dropFirst())
            let expectedAsset = "Caeser-\(name)-macOS-AppleSilicon.dmg"
            guard let asset = release.assets.first(where: { $0.name == expectedAsset && $0.size > 0 && $0.state == "uploaded" }),
                  let page = trustedURL(release.html_url, path: "/cnolli-fl/Caeser/releases/tag/\(release.tag_name)"),
                  let download = trustedURL(asset.browser_download_url, path: "/cnolli-fl/Caeser/releases/download/\(release.tag_name)/\(expectedAsset)")
            else { return nil }
            return (version, ReleaseUpdate(version: name, pageURL: page, downloadURL: download))
        }.max(by: { $0.0 < $1.0 })?.1
    }

    private static func trustedURL(_ text: String, path: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host == "github.com",
              url.path == path, url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

@MainActor
final class ReleaseUpdateModel: ObservableObject {
    @Published private(set) var available: ReleaseUpdate?
    @Published private(set) var isChecking = false
    @Published private(set) var message: String?
    @Published var showsDetails = false
    private var lastCheck: Date?
    private let currentVersion: String
    private let load: @Sendable () async throws -> Data

    init(currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0.0",
         load: @escaping @Sendable () async throws -> Data = { try await ReleaseUpdateModel.loadReleases() }) {
        self.currentVersion = currentVersion
        self.load = load
    }

    func check(manual: Bool = false) async {
        if manual { showsDetails = true }
        guard !isChecking else { return }
        guard manual || lastCheck.map({ Date().timeIntervalSince($0) >= 21_600 }) ?? true else { return }
        isChecking = true
        message = nil
        defer { isChecking = false }
        do {
            available = try ReleaseParser.available(data: await load(), currentVersion: currentVersion)
            lastCheck = Date()
            message = available == nil ? "Você está com a versão mais recente do Caeser para Mac (\(currentVersion))." : nil
        } catch {
            if Task.isCancelled { return }
            // Network/API failures never interrupt downloads or cause a launch alert.
            lastCheck = Date().addingTimeInterval(-18_000) // Retry after one hour.
            message = "Não consegui verificar agora. Confira sua conexão e tente novamente."
        }
    }

    nonisolated static func loadReleases() async throws -> Data {
        let url = URL(string: "https://api.github.com/repos/cnolli-fl/Caeser/releases?per_page=100")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Caeser-macOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 4_000_000 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
