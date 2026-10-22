using System.Collections.ObjectModel;
using System.Text.Json;
using Caeser.Core;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace Caeser.App.ViewModels;
public sealed partial class DownloadViewModel
{
    private readonly LibraryStore libraryStore = new();
    private DesktopLibrary library = new();
    private DispatcherQueue dispatcher = null!;
    private LibraryItem? activeItem;
    private CancellationTokenSource? previewCancellation;
    private bool restoring;
    public MediaPreview? Preview { get; private set; }
    public string? PreviewMessage { get; private set; }
    public bool PreviewBusy { get; private set; }
    public string PreviewTitle => Preview?.Title ?? "";
    public string PreviewCreator => Preview == null ? "" : $"{Preview.Creator} · {Preview.DurationText}";
    public string? PreviewArtwork => Preview?.Artwork;
    public string PreviewMatch => Preview?.MatchedUrl != null ? "Encontrado no YouTube: " + (Preview.MatchTitle ?? Preview.MatchedUrl.AbsoluteUri) :
        Preview?.Count > 1 ? "As versões no YouTube serão buscadas durante o download." : "";
    public Visibility PreviewVisibility => Show(Preview != null);
    public Visibility PreviewBusyVisibility => Show(PreviewBusy);
    public Visibility PreviewMessageVisibility => Show(!string.IsNullOrEmpty(PreviewMessage));
    public Visibility MatchVisibility => Show(Preview?.MatchedUrl != null);
    public ObservableCollection<LibraryItem> QueueItems { get; } = [];
    public IEnumerable<LibraryItem> History => library.Items.Where(i => !i.Pending).OrderByDescending(i => i.Created);
    public Visibility QueueVisibility => Show(QueueItems.Count > 0);
    public string QueueTitle => $"Fila de downloads · {QueueItems.Count}";
    public string PauseTitle => library.Paused ? "Continuar fila" : "Pausar após o atual";
    public ReleaseUpdate? Update { get; private set; }
    public Visibility UpdateVisibility => Show(Update != null);
    public string UpdateMessage { get; private set; } = "";
    private DateTimeOffset lastUpdateCheck = DateTimeOffset.MinValue;
    private bool checkingUpdates;
    private static readonly Version CurrentVersion = typeof(DownloadViewModel).Assembly.GetName().Version ?? new Version(2, 0, 0);
    private DispatcherQueueTimer? updatesTimer;
    private void InitializeLibrary()
    {
        dispatcher = DispatcherQueue.GetForCurrentThread();
        updatesTimer = dispatcher.CreateTimer(); updatesTimer.Interval = TimeSpan.FromHours(6);
        updatesTimer.Tick += async (_, _) => await CheckUpdatesAsync(); updatesTimer.Start();
        try { library = libraryStore.Load(); RestorePreferences(); RefreshLibrary(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException)
        { Append("Não consegui restaurar o histórico: " + e.Message); }
    }
    private void Persist()
    {
        try { libraryStore.Save(library); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException)
        { Append("Não consegui salvar a fila: " + e.Message); }
    }
    private void SavePreferences()
    {
        if (restoring || string.IsNullOrEmpty(Destination)) return;
        library.Preferences[source] = new(new Uri("https://example.invalid"), Destination, source, quality.Value, format.Value);
        Persist();
    }
    private void RestorePreferences()
    {
        restoring = true;
        try
        {
            if (library.Preferences.TryGetValue(source, out var value))
            {
                quality = Qualities.FirstOrDefault(x => x.Value == value.Quality) ?? Qualities[0];
                format = Formats.FirstOrDefault(x => x.Value == value.Format) ?? Formats[0]; Destination = value.Destination;
            }
            else { quality = Qualities[0]; format = Formats[0]; }
        }
        finally { restoring = false; }
    }
    private async void SchedulePreview()
    {
        previewCancellation?.Cancel();
        var cancellation = new CancellationTokenSource(); previewCancellation = cancellation;
        Preview = null; PreviewMessage = null; PreviewBusy = false;
        try
        {
            if (text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length != 1) { Changed(); return; }
            Uri url;
            try { url = DownloadInput.Validate(text, source); } catch (ArgumentException) { Changed(); return; }
            PreviewBusy = true; Changed();
            await Task.Delay(800, cancellation.Token);
            var value = await new PreviewService(tools, new ProcessRunner()).FetchAsync(url, source, cancellation.Token);
            if (!cancellation.IsCancellationRequested) Preview = value;
        }
        catch (OperationCanceledException) { if (previewCancellation == cancellation) PreviewMessage = "A prévia demorou. Tente colar o link novamente ou adicione à fila."; }
        catch (Exception) { if (!cancellation.IsCancellationRequested) PreviewMessage = "Não consegui carregar a prévia. Você ainda pode adicionar o link à fila."; }
        finally { if (previewCancellation == cancellation) { previewCancellation = null; PreviewBusy = false; Changed(); } cancellation.Dispose(); }
    }
    private void RefreshLibrary()
    {
        QueueItems.Clear(); foreach (var item in library.Items.Where(i => i.Pending)) QueueItems.Add(item);
        Changed();
    }
    private void EnqueueInput()
    {
        try
        {
            var requests = DesktopLibrary.Batch(text, source, Destination, quality.Value, format.Value, Preview);
            var additions = new List<LibraryItem>();
            foreach (var request in requests)
            {
                if (library.Items.Concat(additions).Any(i => DesktopLibrary.Key(i.Request) == DesktopLibrary.Key(request) &&
                    (i.Pending || i.State == QueueState.Completed && i.Files.Count > 0 && i.Files.All(File.Exists)))) continue;
                additions.Add(new() { Request = request, Title = Preview?.OriginalUrl == request.Url ? Preview.Title : request.Url.AbsoluteUri,
                    Preview = Preview?.OriginalUrl == request.Url ? Preview : null });
            }
            if (QueueItems.Count + additions.Count > 100) throw new ArgumentException("A fila já tem 100 itens. Espere alguns terminarem.");
            library.Items.AddRange(additions); SavePreferences(); Persist();
            UrlText = ""; if (additions.Count < requests.Count) PreviewMessage = "Links repetidos foram ignorados. Use o Histórico para baixar novamente.";
            RefreshLibrary(); PumpQueue();
        }
        catch (ArgumentException e) { ReportError(e.Message); }
    }
    private void PumpQueue()
    {
        if (IsBusy || library.Paused) return;
        var item = library.Items.FirstOrDefault(i => i.State == QueueState.Waiting);
        if (item == null) return;
        activeItem = item; item.State = QueueState.Downloading; item.Detail = "Baixando…"; Persist(); RefreshLibrary();
        activeTask = RunAsync(item);
    }
    public void TogglePause() { library.Paused = !library.Paused; Persist(); Changed(); PumpQueue(); }
    public void Remove(LibraryItem item) { if (item.State == QueueState.Waiting) library.Items.Remove(item); Persist(); RefreshLibrary(); }
    public void Move(LibraryItem item, int direction)
    {
        var waiting = library.Items.Where(i => i.State == QueueState.Waiting).ToList(); var index = waiting.IndexOf(item);
        if (index < 0 || index + direction < 0 || index + direction >= waiting.Count) return;
        var a = library.Items.IndexOf(item); var b = library.Items.IndexOf(waiting[index + direction]);
        (library.Items[a], library.Items[b]) = (library.Items[b], library.Items[a]); Persist(); RefreshLibrary();
    }
    public void Retry(LibraryItem item)
    {
        if (QueueItems.Count >= 100 || library.Items.Any(i => i.Pending && DesktopLibrary.Key(i.Request) == DesktopLibrary.Key(item.Request))) return;
        library.Items.Add(new() { Request = item.Request, Title = item.Title, Preview = item.Preview }); Persist(); RefreshLibrary(); PumpQueue();
    }
    public void ClearHistory() { library.Items.RemoveAll(i => !i.Pending); Persist(); Changed(); }
    internal void ConfigureFeatureSmoke()
    {
        previewCancellation?.Cancel();
        var url = new Uri("https://youtube.com/watch?v=caeser-ui-fixture");
        Preview = new(url, "Áudio de teste · Caeser", "Prévia de demonstração para teste da interface", null, 183);
        PreviewBusy = false;
        library = new DesktopLibrary { Paused = true, Items = [
            new() { Request = new(url, Destination, DownloadSource.Video, Format: VideoFormat.Mp3), Title = "Primeiro download de teste" },
            new() { Request = new(new Uri("https://youtube.com/watch?v=caeser-ui-second"), Destination, DownloadSource.Video), Title = "Segundo download de teste" },
            new() { Request = new(url, Destination, DownloadSource.Video), Title = "Download anterior", State = QueueState.Completed, Detail = "Concluído" }
        ] };
        RefreshLibrary();
        if (QueueItems.Count != 2 || History.Count() != 1 || PreviewVisibility != Visibility.Visible)
            throw new InvalidOperationException("As novas funções não atualizaram a interface.");
        Move(QueueItems[1], -1);
        if (QueueItems[0].Title != "Segundo download de teste") throw new InvalidOperationException("A ordem da fila não mudou.");
    }
    private void ReceiveLibraryLine(string line)
    {
        if (activeItem == null) return;
        try
        {
            if (line.StartsWith("CAESER_TITLE:")) activeItem.Title = JsonSerializer.Deserialize<string>(line[13..]) ?? activeItem.Title;
            if (line.StartsWith("CAESER_FILE:"))
            { var file = JsonSerializer.Deserialize<string>(line[12..]); if (file != null && Path.IsPathFullyQualified(file) && !activeItem.Files.Contains(file)) activeItem.Files.Add(file); }
        }
        catch (JsonException) { }
    }
    public async Task CheckUpdatesAsync(bool force = false)
    {
        if (checkingUpdates || !force && DateTimeOffset.Now - lastUpdateCheck < TimeSpan.FromHours(6)) return;
        checkingUpdates = true;
        try
        {
            Update = await ReleaseUpdates.CheckAsync(CurrentVersion);
            UpdateMessage = Update == null ? $"Você está com a versão mais recente do Caeser para Windows ({CurrentVersion.ToString(3)})." : $"Caeser {Update.Version} está disponível.";
        }
        catch (Exception) { UpdateMessage = "Não consegui verificar agora. Confira sua conexão e tente novamente."; }
        finally { lastUpdateCheck = DateTimeOffset.Now; checkingUpdates = false; Changed(); }
    }
}
