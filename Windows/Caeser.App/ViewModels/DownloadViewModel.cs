using System.Collections.Concurrent;
using System.ComponentModel;
using Caeser.Core;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace Caeser.App.ViewModels;

public sealed record Choice<T>(string Label, T Value);

public sealed partial class DownloadViewModel : INotifyPropertyChanged
{
    private readonly SettingsStore settings = new();
    private readonly ToolLocator tools = new(AppContext.BaseDirectory);
    private readonly ConcurrentQueue<string> pending = new();
    private readonly List<string> log = [];
    private readonly DispatcherQueueTimer timer;
    private DownloadProgress progress = new();
    private CancellationTokenSource? cancellation;
    private Task? activeTask;
    private DownloadSource activeSource;
    private string text = "";
    private DownloadSource source;
    private Choice<VideoFormat> format;
    private Choice<VideoQuality> quality;

    public DownloadViewModel(DispatcherQueue dispatcher)
    {
        Destination = settings.LoadDestination() ?? PlatformServices.DownloadsPath();
        format = Formats[0]; quality = Qualities[0];
        timer = dispatcher.CreateTimer();
        timer.Interval = TimeSpan.FromMilliseconds(100);
        timer.Tick += (_, _) => FlushOutput();
        RefreshTools();
        InitializeLibrary();
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    // WinUI's all-properties notification uses an empty name, not WPF's null.
    private void Changed() => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(string.Empty));
    public static IReadOnlyList<Choice<VideoQuality>> Qualities { get; } =
    [
        new("Melhor disponível", VideoQuality.Best), new("Até 4K (2160p)", VideoQuality.P2160),
        new("Até 1440p", VideoQuality.P1440), new("Até 1080p", VideoQuality.P1080),
        new("Até 720p", VideoQuality.P720), new("Até 480p", VideoQuality.P480)
    ];
    public static IReadOnlyList<Choice<VideoFormat>> Formats { get; } =
    [
        new("Automático", VideoFormat.Automatic), new("MP4", VideoFormat.Mp4),
        new("WebM", VideoFormat.WebM), new("MP3", VideoFormat.Mp3)
    ];
    public IReadOnlyList<Choice<VideoQuality>> QualityChoices => Qualities;
    public IReadOnlyList<Choice<VideoFormat>> FormatChoices => Formats;

    public string UrlText
    {
        get => text;
        set
        {
            if (text == value) return;
            text = value; Error = null;
            if (DownloadInput.IsSpotify(value) && source != DownloadSource.Spotify) { SavePreferences(); source = DownloadSource.Spotify; RestorePreferences(); }
            SchedulePreview();
            Changed();
        }
    }
    public DownloadSource Source
    {
        get => source;
        set { if (source != value) { SavePreferences(); source = value; RestorePreferences(); Error = null; SchedulePreview(); Changed(); } }
    }
    public Choice<VideoQuality> Quality
    { get => quality; set { if (value != null && quality != value) { quality = value; SavePreferences(); Changed(); } } }
    public Choice<VideoFormat> Format
    { get => format; set { if (value != null && format != value) { format = value; SavePreferences(); Changed(); } } }
    public string Destination { get; private set; }
    public string? LastDestination { get; private set; }
    public bool IsBusy { get; private set; }
    public bool IsIdle => !IsBusy;
    public bool HasResult { get; private set; }
    public bool Succeeded { get; private set; }
    public string? Error { get; private set; }
    public string Status { get; private set; } = "Pronto para o próximo download";
    public string Speed => progress.Speed;
    public string Eta => progress.Eta;
    public string Logs => log.Count == 0 ? "O andamento e os detalhes do download aparecem aqui." : string.Join('\n', log);
    public bool HasLogs => log.Count > 0;
    public bool CanStart => !string.IsNullOrWhiteSpace(text);
    public string ActionTitle => IsBusy || library.Paused || text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length > 1 ? "Adicionar à fila" :
        Source == DownloadSource.Spotify || Format.Value == VideoFormat.Mp3 ? "Baixar MP3" : "Baixar";
    public string ActionGlyph => "\uE896";
    public string LinkLabel => Source == DownloadSource.Spotify ? "Link do Spotify" : "Link do vídeo";
    public string Placeholder => Source == DownloadSource.Spotify ? "https://open.spotify.com/track/…" : "https://www.youtube.com/watch?v=…";
    public string LinkHelp => Source == DownloadSource.Spotify ? "Música, álbum ou playlist pública. Sem entrar na sua conta." :
        "Cole um link ou vários, um por linha.";
    public Visibility VideoVisibility => Show(Source == DownloadSource.Video);
    public Visibility SpotifyVisibility => Show(Source == DownloadSource.Spotify);
    public Visibility QualityVisibility => Show(Format.Value != VideoFormat.Mp3);
    public Visibility AudioQualityVisibility => Show(Format.Value == VideoFormat.Mp3);
    public Visibility ActivityVisibility => Show(IsBusy || HasResult || Error != null);
    public Visibility BusyVisibility => Show(IsBusy);
    public Visibility ErrorVisibility => Show(Error != null);
    public Visibility RevealVisibility => Show(Succeeded && LastDestination != null);
    public bool IsIndeterminate => progress.Fraction == null;
    public double Percent => Succeeded ? 100 : (progress.Fraction ?? 0) * 100;
    public string ToolStatus => tools.Missing(Source).Count == 0 ? "Tudo pronto para baixar · ferramentas incluídas" :
        "Pacote incompleto: " + string.Join(", ", tools.Missing(Source));
    public string ToolDetails { get; private set; } = "";
    public static Visibility Show(bool value) => value ? Visibility.Visible : Visibility.Collapsed;

    public void RefreshTools()
    {
        ToolDetails = string.Join('\n', ToolLocator.RequiredNames.Select(n =>
            $"{(File.Exists(tools.Tool(n)) ? "Disponível" : "Não encontrado")} · {n}"));
        Changed();
    }
    public void ChooseDestination(string destination)
    {
        Destination = destination;
        try { settings.SaveDestination(destination); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        { Append("Não consegui lembrar a pasta para a próxima abertura: " + e.Message); }
        SavePreferences(); Changed();
    }
    public void ClearLogs() { if (!IsBusy) { log.Clear(); Changed(); } }
    public void ReportError(string message) { Error = message; Status = "Precisa de atenção"; Succeeded = false; Changed(); }

    public Task StartAsync()
    {
        EnqueueInput();
        return Task.CompletedTask;
    }
    private async Task RunAsync(LibraryItem item)
    {
        var request = item.Request;
        Error = null; IsBusy = true; HasResult = false; Succeeded = false;
        progress = new(); log.Clear(); activeSource = request.Source;
        cancellation = new();
        LastDestination = request.Destination;
        Status = request.Source == DownloadSource.Spotify ? "Identificando as músicas do Spotify…" : "Preparando download…";
        Append(request.Source == DownloadSource.Spotify ?
            "Spotify identifica as músicas. O áudio será buscado no YouTube e salvo em MP3." : "Iniciando yt-dlp…");
        Append($"Destino: {Destination}");
        Changed(); timer.Start();
        try
        {
            var session = new DownloadSession(tools, new ProcessRunner());
            var result = await session.RunAsync(request, line => pending.Enqueue(line), cancellation.Token);
            FlushOutput();
            if (result.Cancelled) { Status = "Download cancelado"; item.State = QueueState.Cancelled; }
            else if (result.Succeeded)
            {
                Succeeded = true; Status = "Download concluído"; item.State = QueueState.Completed;
                if (request.Source == DownloadSource.Spotify && request.Url.AbsolutePath.Contains("/track/"))
                {
                    var suffix = $"[{request.Url.Segments.Last()}].mp3";
                    item.Files = Directory.EnumerateFiles(request.Destination).Where(f => f.EndsWith(suffix, StringComparison.OrdinalIgnoreCase)).ToList();
                }
            }
            else
            {
                Error = result.Error ?? "Não consegui concluir o download. Confira os detalhes.";
                Status = "Precisa de atenção";
                item.State = QueueState.Failed;
            }
            Append(Error ?? Status);
        }
        catch (Exception e)
        {
            Error = "Não consegui concluir o download: " + e.Message;
            item.State = QueueState.Failed;
            Status = "Precisa de atenção"; Append(Error);
        }
        finally
        {
            timer.Stop(); cancellation.Dispose(); cancellation = null;
            IsBusy = false; HasResult = true; Changed();
            item.Detail = Error ?? Status; activeItem = null; Persist(); RefreshLibrary();
            dispatcher.TryEnqueue(PumpQueue);
        }
    }
    public void Cancel()
    {
        if (!IsBusy) return;
        Status = "Cancelando…"; Changed(); cancellation?.Cancel();
    }
    public async Task CancelAndWaitAsync()
    {
        library.Paused = true; Persist();
        Cancel();
        if (activeTask != null) await activeTask;
    }
    private void FlushOutput()
    {
        var changed = false;
        while (pending.TryDequeue(out var line))
        {
            var clean = progress.Receive(line, activeSource);
            ReceiveLibraryLine(line);
            if (clean.Length == 0) continue;
            Append(clean); changed = true;
        }
        if (changed)
        {
            if (cancellation?.IsCancellationRequested != true) Status = progress.Status;
            Changed();
        }
    }
    private void Append(string line)
    {
        log.Add(line);
        if (log.Count > 600) log.RemoveRange(0, log.Count - 600);
    }
}
