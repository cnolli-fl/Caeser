import SwiftUI

enum AppRelease {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.1.1"
}

/// Local, versioned notes: opening the app never needs a network request for this screen.
struct ReleaseHighlights {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    let version: String
    var pageURL: URL { URL(string: "https://github.com/cnolli-fl/Caeser/releases/tag/v\(version)")! }
    var items: [Item] {
        switch version {
        case "3.1.1":
            return [
                Item(symbol: "sparkles", title: "As novidades, aqui no app",
                     detail: "Veja o que mudou na primeira abertura de cada versão. Depois, consulte novamente pelo menu Caeser."),
                Item(symbol: "book.closed", title: "Primeira abertura mais clara",
                     detail: "O instalador inclui um guia sobre o aviso de verificação do macOS e a autorização individual do aplicativo."),
                Item(symbol: "tray.full", title: "Tudo no seu lugar",
                     detail: "O visual azul, sua fila, histórico e preferências continuam como antes.")
            ]
        default:
            // An unknown version must not display an older release's features as its own.
            return [Item(symbol: "doc.text", title: "Uma nova versão do Caeser",
                         detail: "Consulte as notas completas desta versão para conhecer as mudanças.")]
        }
    }
}

@MainActor
final class WhatsNewModel: ObservableObject {
    private static let seenKey = "whatsNew.lastSeenVersion"
    let highlights: ReleaseHighlights
    private let defaults: UserDefaults
    private var requestedThisSession = false

    init(defaults: UserDefaults = .standard, version: String = AppRelease.version) {
        self.defaults = defaults
        self.highlights = ReleaseHighlights(version: version)
    }

    func requestAutomaticPresentation() -> Bool {
        guard !requestedThisSession,
              let current = ReleaseVersion(highlights.version) else { return false }
        requestedThisSession = true
        if let seen = defaults.string(forKey: Self.seenKey).flatMap(ReleaseVersion.init), seen >= current {
            return false
        }
        return true
    }

    func markPresented() {
        guard let current = ReleaseVersion(highlights.version) else { return }
        if let seen = defaults.string(forKey: Self.seenKey).flatMap(ReleaseVersion.init), seen >= current { return }
        defaults.set(highlights.version, forKey: Self.seenKey)
    }
}

struct WhatsNewView: View {
    @ObservedObject var model: WhatsNewModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                CaeserLogo()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("O que mudou").font(.title.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Caeser para Mac · \(model.highlights.version)")
                        .font(.body).foregroundStyle(OceanPalette.secondaryText)
                }
            }
            .padding(28)
            Divider().overlay(OceanPalette.border.opacity(0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(model.highlights.items) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: item.symbol)
                                .font(.title2).foregroundStyle(OceanPalette.accent)
                                .frame(width: 28, height: 28).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.body)
                                    .foregroundStyle(OceanPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().overlay(OceanPalette.border.opacity(0.4))
            HStack {
                Link("Notas completas ↗", destination: model.highlights.pageURL)
                    .frame(minHeight: 28)
                Spacer()
                Button("Continuar") { dismissWindow(id: "whats-new") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28).padding(.vertical, 20)
        }
        .foregroundStyle(.white)
        .background(OceanPalette.canvas)
        .tint(OceanPalette.accent)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 440, idealHeight: 520)
        .onAppear { model.markPresented() }
    }
}

struct WhatsNewLaunchModifier: ViewModifier {
    @ObservedObject var model: WhatsNewModel
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.task {
            // The download window is ready first; this separate window never blocks downloads.
            await Task.yield()
            guard !Task.isCancelled, model.requestAutomaticPresentation() else { return }
            openWindow(id: "whats-new")
        }
    }
}
