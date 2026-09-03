import AppKit
import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var viewModel = DownloadViewModel()

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    settings
                    progressSection
                    logsSection
                    actionBar
                }
                .padding(28)
                .frame(maxWidth: 780)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .tint(.cyan)
        .alert("Não foi possível baixar", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Ocorreu um erro inesperado.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                SVGLogoView()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.20), lineWidth: 1)
                    }
                    .shadow(color: .purple.opacity(0.35), radius: 12, y: 4)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Caeser")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Baixe vídeos usando yt-dlp e FFmpeg instalados pelo Homebrew.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("MACOS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
                Text("yt-dlp + FFmpeg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 24)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("URL do vídeo")
                    .font(.headline)
                TextField("https://www.youtube.com/watch?v=…", text: $viewModel.urlText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }
                    .onSubmit { viewModel.startDownload() }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Qualidade")
                        .font(.headline)
                    Picker("Qualidade", selection: $viewModel.quality) {
                        ForEach(VideoQuality.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(viewModel.format == .mp3)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Formato")
                        .font(.headline)
                    Picker("Formato", selection: $viewModel.format) {
                        ForEach(VideoFormat.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.format == .mp3 {
                Label(
                    "MP3 usa a melhor faixa de áudio disponível e a qualidade máxima do FFmpeg (0).",
                    systemImage: "waveform"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Pasta de destino")
                    .font(.headline)
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.cyan)
                    Text(viewModel.destinationURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Alterar…") {
                        viewModel.chooseDestination()
                    }
                    .disabled(viewModel.isDownloading)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
            }

            dependencyStatus
        }
        .padding(20)
        .liquidGlass(cornerRadius: 24)
    }

    private var dependencyStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.dependencyInfo.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(viewModel.dependencyInfo.isReady ? .green : .orange)
            Text(viewModel.dependencyInfo.message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Verificar novamente") {
                viewModel.refreshDependencies()
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        if viewModel.isDownloading || viewModel.progress != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.statusMessage)
                        .font(.headline)
                    Spacer()
                    if !viewModel.speedText.isEmpty {
                        Text(viewModel.speedText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: viewModel.progress)
                if !viewModel.etaText.isEmpty {
                    Text(viewModel.etaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .liquidGlass(cornerRadius: 18)
        }
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Logs")
                    .font(.headline)
                Spacer()
                if !viewModel.logLines.isEmpty {
                    Button("Limpar") {
                        viewModel.clearLogs()
                    }
                    .buttonStyle(.link)
                    .disabled(viewModel.isDownloading)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if viewModel.logLines.isEmpty {
                            Text("As mensagens do yt-dlp aparecerão aqui.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(minHeight: 130, maxHeight: 210)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
                .onChange(of: viewModel.logLines.count) { newCount in
                    guard newCount > 0 else { return }
                    withAnimation {
                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                    }
                }
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 24)
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            if viewModel.isDownloading {
                Button("Cancelar") {
                    viewModel.cancelDownload()
                }
                .keyboardShortcut(.cancelAction)
            } else {
                Button("Baixar") {
                    viewModel.startDownload()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartDownload)
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }
}

private struct LiquidBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.045, blue: 0.09),
                    Color(red: 0.055, green: 0.025, blue: 0.10),
                    Color(red: 0.015, green: 0.055, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.cyan.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -280, y: -280)

            Circle()
                .fill(.purple.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: 300, y: 260)

            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 85)
                .offset(x: 280, y: -240)
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        self.glassEffect(
            .regular.tint(.white.opacity(0.07)),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct SVGLogoView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.underPageBackgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground")

        guard let svgURL = Bundle.main.url(forResource: "CaeserIcon", withExtension: "svg"),
              let svg = try? String(contentsOf: svgURL, encoding: .utf8) else {
            return webView
        }

        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <style>
                html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; }
                svg { display: block; width: 100%; height: 100%; }
            </style>
        </head>
        <body>\(svg)</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: svgURL.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
