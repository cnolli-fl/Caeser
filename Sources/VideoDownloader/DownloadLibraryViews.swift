import SwiftUI

struct MediaArtwork: View {
    let url: URL?
    var width: CGFloat = 64
    var height: CGFloat = 64
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor).opacity(0.25)
                    Image(systemName: "music.note.tv").font(.title2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct MediaPreviewView: View {
    let preview: MediaPreview
    let source: DownloadSource
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                MediaArtwork(url: preview.artworkURL, width: source == .spotify ? 64 : 104)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preview.title).font(.headline).lineLimit(3).help(preview.title)
                    if !preview.creator.isEmpty {
                        Text(preview.creator).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if let duration = preview.durationText {
                        Label(duration, systemImage: "clock").font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if source == .spotify {
                if let match = preview.matchedURL {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label("Encontrado no YouTube", systemImage: "checkmark.circle")
                                .font(.callout.weight(.medium))
                            Spacer(minLength: 8)
                            Link("Conferir ↗", destination: match).font(.callout)
                                .help("Abrir o vídeo correspondente no navegador")
                                .accessibilityLabel("Conferir a versão encontrada no YouTube")
                        }
                        if let video = preview.matchedVideo {
                            Text(video.title).font(.callout).lineLimit(2).help(video.title)
                            Text([video.creator, video.durationText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(preview.trackCount > 1 ? "As versões no YouTube serão buscadas durante o download da coleção."
                         : "A versão no YouTube será buscada ao baixar.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Prévia do download")
    }
}

struct DownloadQueueView: View {
    @ObservedObject var model: DownloadViewModel
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fila de downloads").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("\(model.queuedItems.count)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button(model.isQueuePaused ? "Continuar" : "Pausar fila",
                       systemImage: model.isQueuePaused ? "play" : "pause") { model.toggleQueuePause() }
                    .buttonStyle(.borderless).frame(minHeight: 28)
                    .help("Pausar a fila deixa o download atual terminar antes de parar.")
            }
            if model.isQueuePaused {
                Text(model.isDownloading ? "A fila vai pausar quando o download atual terminar." : "Fila pausada. Continue quando quiser.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            let visible = expanded ? model.queuedItems : Array(model.queuedItems.prefix(4))
            VStack(spacing: 14) {
                ForEach(visible) { item in
                    queueRow(item)
                    if item.id != visible.last?.id { Divider() }
                }
            }
            if model.queuedItems.count > 4 {
                Button(expanded ? "Mostrar menos" : "Mostrar mais \(model.queuedItems.count - 4)",
                       systemImage: expanded ? "chevron.up" : "chevron.down") { expanded.toggle() }
                    .buttonStyle(.borderless).frame(minHeight: 28)
            }
        }
        .padding(.horizontal, 4)
    }

    private func queueRow(_ item: QueueItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MediaArtwork(url: item.request.preview?.artworkURL, width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(.body.weight(.medium)).lineLimit(2).help(item.title)
                Text("\(item.request.source.rawValue) · \(item.request.format.rawValue)")
                    .font(.callout).foregroundStyle(.secondary)
                if item.status == .downloading {
                    ProgressView(value: item.progress).progressViewStyle(.linear)
                        .accessibilityLabel("Progresso de \(item.title)")
                    HStack {
                        Text(item.detail)
                        Spacer(minLength: 6)
                        Text(model.speedText)
                    }
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Label(item.status.title, systemImage: item.status.symbol)
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.status == .downloading {
                Button("Cancelar download", systemImage: "xmark") { model.cancelDownload() }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).frame(width: 28, height: 28)
                    .help("Cancelar apenas este download")
            } else {
                Menu {
                    Button("Mover para cima", systemImage: "arrow.up") { model.moveInQueue(item.id, earlier: true) }
                    Button("Mover para baixo", systemImage: "arrow.down") { model.moveInQueue(item.id, earlier: false) }
                    Divider()
                    Button("Remover da fila", systemImage: "xmark") { model.removeFromQueue(item.id) }
                } label: { Label("Opções de \(item.title)", systemImage: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).labelStyle(.iconOnly)
                .frame(width: 28, height: 28).help("Organizar ou remover este download")
            }
        }
        .accessibilityElement(children: .contain)
        .help("Salvar em: \(item.request.destination.path)")
    }
}

struct DownloadHistoryView: View {
    @ObservedObject var model: DownloadViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Histórico").font(.title2.weight(.semibold))
                    Text("Seus últimos 100 downloads, salvos neste Mac.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Concluído") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if model.history.isEmpty {
                ContentUnavailableView("Nenhum download ainda", systemImage: "clock.arrow.circlepath",
                                       description: Text("Os downloads concluídos, cancelados ou com erro aparecem aqui."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(model.history) { item in
                            HStack(alignment: .top, spacing: 12) {
                                MediaArtwork(url: item.request.preview?.artworkURL, width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.body.weight(.medium)).lineLimit(2).help(item.title)
                                    Label(item.status.title, systemImage: item.status.symbol)
                                        .font(.callout).foregroundStyle(.secondary)
                                    if item.status == .failed || item.status == .interrupted {
                                        Text(item.detail).font(.callout).foregroundStyle(.secondary)
                                    }
                                    Text(item.finishedAt ?? item.createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Mostrar no Finder", systemImage: "folder") { model.reveal(item) }
                                    .labelStyle(.iconOnly).frame(width: 28, height: 28).help("Mostrar no Finder")
                                Button(item.status == .completed ? "Baixar novamente" : "Tentar novamente",
                                       systemImage: "arrow.clockwise") { model.retry(item); dismiss() }
                                    .labelStyle(.iconOnly).frame(width: 28, height: 28).help("Adicionar novamente à fila")
                            }
                            .buttonStyle(.borderless)
                            Divider()
                        }
                    }
                }
                Button("Limpar histórico…") { confirmClear = true }.buttonStyle(.borderless)
            }
        }
        .padding(24).frame(width: 580, height: 460)
        .alert("Limpar o histórico?", isPresented: $confirmClear) {
            Button("Cancelar", role: .cancel) { }
            Button("Limpar histórico", role: .destructive) { model.clearHistory() }
        } message: { Text("Só os registros serão removidos. Os arquivos baixados continuam na sua pasta.") }
    }
}

struct ReleaseUpdateView: View {
    @ObservedObject var model: ReleaseUpdateModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Atualizações do Caeser", systemImage: "arrow.down.circle")
                .font(.title2.weight(.semibold))
            if model.isChecking {
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text("Verificando atualizações…") }
            } else if let update = model.available {
                Text("A versão \(update.version) está disponível.").font(.headline)
                Text("Baixe a atualização e substitua o Caeser na pasta Aplicativos. Sua fila, histórico e preferências são mantidos.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Link("Ver novidades ↗", destination: update.pageURL)
                HStack {
                    Button("Depois") { dismiss() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Link("Baixar atualização…", destination: update.downloadURL)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text(model.message ?? "Verifique se há uma versão nova para o seu Mac.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Verificar novamente") { Task { await model.check(manual: true) } }
                    Spacer()
                    Button("Concluído") { dismiss() }.keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(24).frame(width: 400).tint(.purple)
    }
}
