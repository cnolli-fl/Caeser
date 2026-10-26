import AppKit
import ImageIO
import SwiftUI

@MainActor
struct ContentView: View {
    @ObservedObject var viewModel: DownloadViewModel
    @ObservedObject var updates: ReleaseUpdateModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var linkFocused: Bool
    @State private var showDetails = false

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    downloadForm
                    if !viewModel.queuedItems.isEmpty {
                        DownloadQueueView(model: viewModel)
                    }
                    if viewModel.isInstalling || (viewModel.queuedItems.isEmpty &&
                        (viewModel.hasResult || viewModel.errorMessage != nil)) {
                        activity
                    }
                    if let message = viewModel.persistenceMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(OceanPalette.secondaryText)
                    }
                    details
                }
                .padding(32)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(OceanPalette.accent)
        .sheet(isPresented: $viewModel.showsHistory) { DownloadHistoryView(model: viewModel) }
        .sheet(isPresented: $updates.showsDetails) { ReleaseUpdateView(model: updates) }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if updates.available != nil {
                    Button("Atualizar", systemImage: "arrow.down.circle") { updates.showsDetails = true }
                        .labelStyle(.titleAndIcon).help("Uma nova versão do Caeser está disponível")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Histórico", systemImage: "clock.arrow.circlepath") { viewModel.showsHistory = true }
                    .help("Ver o histórico de downloads")
            }
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isInstalling {
                    Button("Cancelar", systemImage: "xmark") { viewModel.cancelDownload() }
                        .labelStyle(.titleAndIcon)
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.glass)
                } else {
                    Button(downloadActionTitle,
                           systemImage: viewModel.errorMessage == nil ? "arrow.down" : "arrow.clockwise") {
                        viewModel.startDownload()
                    }
                        .labelStyle(.titleAndIcon)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.glassProminent)
                        .disabled(!viewModel.canStartDownload)
                }
            }
        }
        .onAppear { linkFocused = true; viewModel.refreshDependencies() }
        .task {
            await updates.check()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(21_600)) } catch { return }
                await updates.check()
            }
        }
        .onChange(of: scenePhase) { if scenePhase == .active { Task { await updates.check() } } }
    }

    private var downloadActionTitle: String {
        if viewModel.isQueuePaused { return "Baixar e continuar fila" }
        if viewModel.isDownloading { return "Adicionar e baixar" }
        if viewModel.inputLinkCount > 1 { return "Baixar todos" }
        return viewModel.effectiveFormat == .mp3 ? "Baixar MP3" : "Baixar"
    }

    private var background: some View {
        OceanPalette.canvas.ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 16) {
            CaeserLogo()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Caeser")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Text("Vídeos e músicas. Do link à sua pasta.")
                    .font(.body)
                    .foregroundStyle(OceanPalette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var downloadForm: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Novo download").font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            SourceSelector(selection: $viewModel.source)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(viewModel.source == .spotify ? "Link do Spotify" : "Link do vídeo")
                        .font(.headline)
                    Spacer()
                    Button("Colar", systemImage: "clipboard") {
                        viewModel.pasteLink()
                        linkFocused = true
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                    .frame(minHeight: 28)
                    .help("Colar um link da área de transferência")
                }
                TextField(viewModel.source == .spotify ? "https://open.spotify.com/track/…" : "https://www.youtube.com/watch?v=…",
                          text: $viewModel.urlText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(OceanPalette.selectionTrack, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(OceanPalette.border.opacity(0.7), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .controlSize(.large)
                    .font(.body)
                    .focused($linkFocused)
                    .accessibilityLabel(viewModel.source == .spotify ? "Link do Spotify" : "Link do vídeo")
                    .onSubmit { viewModel.startDownload() }
                Text(viewModel.inputLinkCount > 1 ? "\(viewModel.inputLinkCount) links · cada um entra na fila com estas opções." : viewModel.source == .spotify
                     ? "Música, álbum ou playlist pública. Sem entrar na sua conta."
                     : "Cole um link ou vários, um por linha.")
                    .font(.callout)
                    .foregroundStyle(OceanPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let message = viewModel.inputMessage {
                    Label(message, systemImage: "info.circle").font(.callout).foregroundStyle(OceanPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if viewModel.isLoadingPreview {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Buscando prévia…").font(.callout).foregroundStyle(OceanPalette.secondaryText)
                    }
                    .frame(minHeight: 32).accessibilityElement(children: .combine)
                } else if let preview = viewModel.preview {
                    MediaPreviewView(preview: preview, source: viewModel.source)
                } else if let error = viewModel.previewError {
                    HStack(alignment: .top, spacing: 12) {
                        Text(error).font(.callout).foregroundStyle(OceanPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Tentar prévia") { viewModel.schedulePreview(immediate: true) }
                            .buttonStyle(.borderless).frame(minHeight: 28)
                    }
                }
            }

            Divider()

            Group {
                if viewModel.source == .spotify {
                    spotifyExplanation.transition(.opacity)
                } else {
                    videoOptions.transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: viewModel.source)

            Divider()
            destination
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(OceanPalette.surface.opacity(reduceTransparency ? 1 : 0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(OceanPalette.border.opacity(contrast == .increased ? 1 : 0.55),
                              lineWidth: contrast == .increased ? 1.5 : 0.5)
        }
        .disabled(viewModel.isInstalling)
    }

    private var spotifyExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label { Text("Spotify") } icon: { SourceBrandIcon(source: .spotify) }
                Image(systemName: "arrow.right").foregroundStyle(OceanPalette.secondaryText).accessibilityHidden(true)
                Label { Text("YouTube") } icon: { SourceBrandIcon(source: .video) }
                Spacer(minLength: 6)
                Text("MP3").font(.callout.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
            .font(.body.weight(.medium))
            Text("O áudio vem do YouTube. O MP3 inclui capa, artista e álbum.")
                .font(.callout).foregroundStyle(OceanPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Label("Melhor áudio disponível",
                  systemImage: "waveform")
                .font(.callout)
            Text("A busca é automática e pode encontrar outra versão da música.")
                .font(.callout).foregroundStyle(OceanPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var videoOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Qualidade").font(.headline)
                    if viewModel.format == .mp3 {
                        Text("Melhor áudio disponível")
                            .font(.body).foregroundStyle(OceanPalette.secondaryText)
                            .frame(minHeight: 28, alignment: .leading)
                    } else {
                        Picker("Qualidade", selection: $viewModel.quality) {
                            ForEach(VideoQuality.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 9) {
                    Text("Formato").font(.headline)
                    Picker("Formato", selection: $viewModel.format) {
                        ForEach(VideoFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().controlSize(.large)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if viewModel.format == .mp3 {
                Text("Converte a melhor faixa de áudio disponível para MP3 em qualidade máxima.")
                    .font(.callout).foregroundStyle(OceanPalette.secondaryText)
            }
        }
    }

    private var destination: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder").font(.title3).foregroundStyle(OceanPalette.secondaryText).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Salvar em").font(.callout).foregroundStyle(OceanPalette.secondaryText)
                Text((viewModel.destinationURL.path as NSString).abbreviatingWithTildeInPath)
                    .font(.body.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    .help(viewModel.destinationURL.path)
                    .accessibilityLabel("Pasta de destino: \(viewModel.destinationURL.path)")
            }
            Spacer()
            Button("Alterar…") { viewModel.chooseDestination() }
                .controlSize(.regular)
                .frame(minHeight: 28)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if !viewModel.isBusy {
                    Image(systemName: viewModel.succeeded ? "checkmark.circle.fill" :
                            (viewModel.errorMessage == nil ? "pause.circle" : "exclamationmark.circle.fill"))
                        .foregroundStyle(viewModel.succeeded ? Color.green :
                            (viewModel.errorMessage != nil ? Color.red : Color.secondary))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.statusMessage).font(.headline)
                    if let error = viewModel.errorMessage {
                        Text(error).font(.callout).foregroundStyle(OceanPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
                if viewModel.canRevealDownload {
                    Button("Mostrar no Finder", systemImage: "folder") { viewModel.revealDownload() }
                        .buttonStyle(.link)
                }
            }
            if viewModel.isBusy {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(viewModel.statusMessage)
                HStack {
                    Text(viewModel.speedText)
                    Spacer()
                    Text(viewModel.etaText)
                }
                .font(.callout).foregroundStyle(OceanPalette.secondaryText).monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: viewModel.dependenciesReady ? "checkmark.circle" : "shippingbox")
                    .foregroundStyle(OceanPalette.secondaryText).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.dependencyMessage).font(.callout).foregroundStyle(OceanPalette.secondaryText)
                    if viewModel.source == .spotify && viewModel.dependencyInfo.spotDL == nil {
                        Text("Instale o suporte uma vez. O spotDL fica separado do aplicativo.")
                            .font(.callout).foregroundStyle(OceanPalette.secondaryText)
                        Button("Instalar suporte ao Spotify", systemImage: "arrow.down.circle") {
                            showDetails = true
                            viewModel.installSpotifySupport()
                        }
                        .disabled(viewModel.isBusy)
                        .controlSize(.large)
                    } else if !viewModel.dependenciesReady {
                        Text("No Terminal: brew install yt-dlp ffmpeg")
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }

            DisclosureGroup("Detalhes e ferramentas", isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        toolLabel("yt-dlp", url: viewModel.dependencyInfo.ytDLP)
                        toolLabel("FFmpeg", url: viewModel.dependencyInfo.ffmpeg)
                        toolLabel("spotDL", url: viewModel.dependencyInfo.spotDL)
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Button("Verificar ferramentas", systemImage: "arrow.clockwise") { viewModel.refreshDependencies() }
                        Spacer()
                        Button("Copiar registro", systemImage: "doc.on.doc") {
                            viewModel.copyLogs()
                        }
                        .disabled(viewModel.logLines.isEmpty)
                        Button("Limpar") { viewModel.clearLogs() }.disabled(viewModel.isBusy)
                    }
                    .buttonStyle(.link)
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(viewModel.logLines.isEmpty
                                 ? "O andamento e os detalhes do download aparecem aqui."
                                 : viewModel.logLines.joined(separator: "\n"))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(viewModel.logLines.isEmpty ? .secondary : .primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                            Color.clear.frame(height: 1).id("lastLine")
                        }
                        .frame(height: 155)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .onChange(of: viewModel.logRevision) {
                            if reduceMotion { proxy.scrollTo("lastLine", anchor: .bottom) }
                            else { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("lastLine", anchor: .bottom) } }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .font(.callout)
        }
        .padding(.horizontal, 4)
    }

    private func toolLabel(_ name: String, url: URL?) -> some View {
        Label(name, systemImage: url == nil ? "minus.circle" : "checkmark.circle")
            .foregroundStyle(OceanPalette.secondaryText)
            .help(url?.path ?? "\(name) não está instalado")
            .accessibilityLabel("\(name): \(url == nil ? "não instalado" : "disponível")")
    }
}

private struct SourceSelector: View {
    @Binding var selection: DownloadSource
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var focusedSource: DownloadSource?
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.28, dampingFraction: 0.9)))
    private var dragCenter: CGFloat? = nil

    // Both endpoints keep white labels above 4.5:1.
    private let selectedColors = [Color(red: 0.02, green: 0.43, blue: 0.74),
                                  Color(red: 0.0, green: 0.31, blue: 0.60)]

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / 2
            let center = dragCenter ?? (CGFloat(visualIndex(for: selection)) + 0.5) * segmentWidth
            let highlighted = source(at: center, width: geometry.size.width)

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(OceanPalette.selectionTrack)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: selectedColors, startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(contrast == .increased ? 0.65 : 0.25), lineWidth: 1)
                    }
                    .frame(width: max(0, segmentWidth - 6), height: 34)
                    .position(x: center, y: 20)
                    .animation(reduceMotion || dragCenter != nil ? nil :
                        .spring(response: 0.28, dampingFraction: 0.9), value: selection)

                HStack(spacing: 0) {
                    ForEach(DownloadSource.allCases) { option in
                        Button {
                            guard dragCenter == nil else { return }
                            selection = option
                        } label: {
                            Label { Text(option.rawValue) } icon: { SourceBrandIcon(source: option) }
                                .font(.body.weight(highlighted == option ? .semibold : .medium))
                                .foregroundStyle(highlighted == option ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focused($focusedSource, equals: option)
                        .overlay {
                            if focusedSource == option {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 2)
                                    .padding(2)
                            }
                        }
                        .accessibilityAddTraits(selection == option ? [.isSelected] : [])
                        .accessibilityIdentifier("source-\(option.id.rawValue)")
                        .help(option == .spotify ? "Buscar músicas do Spotify no YouTube" : "Baixar de um link de vídeo")
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(contrast == .increased ? 1 : 0.35),
                                  lineWidth: contrast == .increased ? 1.5 : 0.5)
                    .allowsHitTesting(false)
            }
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .updating($dragCenter) { value, state, transaction in
                        guard isEnabled, abs(value.translation.width) > abs(value.translation.height) else { return }
                        transaction.animation = nil
                        let initial = (CGFloat(visualIndex(for: selection)) + 0.5) * segmentWidth
                        state = min(max(initial + value.translation.width, segmentWidth / 2),
                                    geometry.size.width - segmentWidth / 2)
                    }
                    .onEnded { value in
                        guard isEnabled, abs(value.translation.width) > abs(value.translation.height) else { return }
                        let initial = (CGFloat(visualIndex(for: selection)) + 0.5) * segmentWidth
                        selection = source(at: initial + value.translation.width, width: geometry.size.width)
                    }
            )
            .onMoveCommand { direction in
                guard isEnabled else { return }
                if direction == .left { selection = source(at: 0, width: geometry.size.width) }
                if direction == .right { selection = source(at: geometry.size.width, width: geometry.size.width) }
            }
        }
        .frame(height: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Origem do link")
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private func visualIndex(for source: DownloadSource) -> Int {
        let index = source == .video ? 0 : 1
        return layoutDirection == .rightToLeft ? 1 - index : index
    }

    private func source(at position: CGFloat, width: CGFloat) -> DownloadSource {
        let left = layoutDirection == .rightToLeft ? DownloadSource.spotify : .video
        let right = layoutDirection == .rightToLeft ? DownloadSource.video : .spotify
        return position < width / 2 ? left : right
    }
}

/// Official monochrome marks, kept separate from SF Symbols used for app actions.
struct SourceBrandIcon: View {
    let source: DownloadSource
    @Environment(\.displayScale) private var displayScale

    private static let images: [DownloadSource: [Int: CGImage]] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        var result: [DownloadSource: [Int: CGImage]] = [:]
        for source in DownloadSource.allCases {
            let name = source == .spotify ? "SpotifyMark" : "YouTubeMark"
            for scale in 1...3 {
                let suffix = scale == 1 ? "" : "@\(scale)x"
                guard let url = bundle.url(forResource: name + suffix, withExtension: "png"),
                      let decoder = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(decoder, 0, nil) else { continue }
                result[source, default: [:]][scale] = image
            }
        }
        return result
    }()

    static func image(for source: DownloadSource, scale: Int) -> CGImage? {
        images[source]?[scale]
    }

    static func assetScale(for displayScale: CGFloat) -> Int {
        guard displayScale.isFinite else { return 2 }
        return Int(ceil(min(3, max(1, displayScale))))
    }

    var body: some View {
        let scale = Self.assetScale(for: displayScale)
        Group {
            if let image = Self.image(for: source, scale: scale) {
                // One asset pixel per screen pixel at 1×, 2× and 3×. Avoid a
                // large NSImage template being resized into another cached mask.
                Image(decorative: image, scale: CGFloat(scale), orientation: .up)
                    .renderingMode(.template)
                    .interpolation(.none)
            } else {
                Image(systemName: source.symbol)
            }
        }
        .frame(width: 36, height: 24)
        // The adjacent text labels the brand without repeating it in VoiceOver.
        .accessibilityHidden(true)
    }
}

/// Loads the active branch artwork at full resolution, including on Retina displays.
struct CaeserLogo: View {
    private static let originalImage: NSImage? = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "CaeserLogo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        Group {
            if let original = Self.originalImage {
                Image(nsImage: original)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .foregroundStyle(OceanPalette.secondaryText)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}


/// Reference-blue canvas with light foregrounds and tonal blue controls.
enum OceanPalette {
    static let accent = rgb(0x94D2FF)
    static let canvas = rgb(0x0D2666)
    static let secondaryText = rgb(0xCFDFF5)
    static let surface = canvas
    static let selectionTrack = rgb(0x244580)
    static let border = rgb(0x6086BB)
    static let aqua = rgb(0x63D5E9)

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255,
              blue: Double(hex & 255) / 255)
    }
}
