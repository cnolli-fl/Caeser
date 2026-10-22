using System.Collections.Concurrent;
using System.ComponentModel;
using Caeser.Core;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace Caeser.App.ViewModels;

public sealed record Choice<T>(string Label, T Value);

public sealed class DownloadViewModel : INotifyPropertyChanged
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
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void Changed() => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(null));
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
            if (DownloadInput.IsSpotify(value)) source = DownloadSource.Spotify;
            Changed();
        }
    }
    public DownloadSource Source
    {
        get => source;
        set { if (source != value && !IsBusy) { source = value; Error = null; Changed(); } }
    }
    public Choice<VideoQuality> Quality
    { get => quality; set { if (value != null) { quality = value; Changed(); } } }
    public Choice<VideoFormat> Format
    { get => format; set { if (value != null) { format = value; Changed(); } } }
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
    public bool CanStart => IsBusy || !string.IsNullOrWhiteSpace(text);
    public string ActionTitle => IsBusy ? "Cancelar" : Error != null ? "Tentar novamente" :
        Source == DownloadSource.Spotify || Format.Value == VideoFormat.Mp3 ? "Baixar MP3" : "Baixar";
    public string ActionGlyph => IsBusy ? "\uE711" : Error != null ? "\uE72C" : "\uE896";
    public string LinkLabel => Source == DownloadSource.Spotify ? "Link do Spotify" : "Link do vídeo";
    public string Placeholder => Source == DownloadSource.Spotify ? "https://open.spotify.com/track/…" : "https://www.youtube.com/watch?v=…";
    public string LinkHelp => Source == DownloadSource.Spotify ? "Música, álbum ou playlist pública. Sem entrar na sua conta." :
        "Cole um link do YouTube ou de outro site compatível.";
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
        if (IsBusy) return;
        Destination = destination;
        try { settings.SaveDestination(destination); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        { Append("Não consegui lembrar a pasta para a próxima abertura: " + e.Message); }
        Changed();
    }
    public void ClearLogs() { if (!IsBusy) { log.Clear(); Changed(); } }
    public void ReportError(string message) { Error = message; Status = "Precisa de atenção"; Succeeded = false; Changed(); }

    public Task StartAsync()
    {
        if (IsBusy) return activeTask ?? Task.CompletedTask;
        activeTask = RunAsync();
        return activeTask;
    }
    private async Task RunAsync()
    {
        Uri url;
        try { url = DownloadInput.Validate(UrlText, Source); }
        catch (ArgumentException e) { ReportError(e.Message); return; }
        Error = null; IsBusy = true; HasResult = false; Succeeded = false;
        progress = new(); log.Clear(); activeSource = Source;
        cancellation = new();
        LastDestination = Destination;
        Status = Source == DownloadSource.Spotify ? "Identificando as músicas do Spotify…" : "Preparando download…";
        Append(Source == DownloadSource.Spotify ?
            "Spotify identifica as músicas. O áudio será buscado no YouTube e salvo em MP3." : "Iniciando yt-dlp…");
        Append($"Destino: {Destination}");
        Changed(); timer.Start();
        try
        {
            var session = new DownloadSession(tools, new ProcessRunner());
            var request = new DownloadRequest(url, Destination, Source, Quality.Value, Format.Value);
            var result = await session.RunAsync(request, line => pending.Enqueue(line), cancellation.Token);
            FlushOutput();
            if (result.Cancelled) { Status = "Download cancelado"; }
            else if (result.Succeeded) { Succeeded = true; Status = "Download concluído"; }
            else
            {
                Error = result.Error ?? "Não consegui concluir o download. Confira os detalhes.";
                Status = "Precisa de atenção";
            }
            Append(Error ?? Status);
        }
        catch (Exception e)
        {
            Error = "Não consegui concluir o download: " + e.Message;
            Status = "Precisa de atenção"; Append(Error);
        }
        finally
        {
            timer.Stop(); cancellation.Dispose(); cancellation = null;
            IsBusy = false; HasResult = true; Changed();
        }
    }
    public void Cancel()
    {
        if (!IsBusy) return;
        Status = "Cancelando…"; Changed(); cancellation?.Cancel();
    }
    public async Task CancelAndWaitAsync()
    {
        Cancel();
        if (activeTask != null) await activeTask;
    }
    private void FlushOutput()
    {
        var changed = false;
        while (pending.TryDequeue(out var line))
        {
            var clean = progress.Receive(line, activeSource);
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
