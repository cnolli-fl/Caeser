using System.Text.Json;

namespace Caeser.Core;

public sealed record MediaPreview(Uri OriginalUrl, string Title, string Creator, string? Artwork,
    double? Duration, int Count = 1, Uri? MatchedUrl = null, string? MatchTitle = null)
{
    public string DurationText => Duration is > 0 and < 31536000
        ? TimeSpan.FromSeconds(Duration.Value).ToString(Duration >= 3600 ? @"h\:mm\:ss" : @"m\:ss") : "";
}
public enum QueueState { Waiting, Downloading, Completed, Failed, Cancelled, Interrupted }
public sealed class LibraryItem : System.ComponentModel.INotifyPropertyChanged
{
    public event System.ComponentModel.PropertyChangedEventHandler? PropertyChanged;
    private string title = "", detail = "Na fila";
    public Guid Id { get; set; } = Guid.NewGuid();
    public required DownloadRequest Request { get; set; }
    public MediaPreview? Preview { get; set; }
    public string Title { get => title; set { title = value; PropertyChanged?.Invoke(this, new(nameof(Title))); } }
    public QueueState State { get; set; }
    public string Detail { get => detail; set { detail = value; PropertyChanged?.Invoke(this, new(nameof(Description))); } }
    public List<string> Files { get; set; } = [];
    public DateTimeOffset Created { get; set; } = DateTimeOffset.Now;
    public bool Pending => State is QueueState.Waiting or QueueState.Downloading;
    public string Description => $"{(Request.Source == DownloadSource.Spotify ? "Spotify" : "YouTube")} · {Request.Format} · {Detail}";
}
public sealed class DesktopLibrary
{
    public List<LibraryItem> Items { get; set; } = [];
    public bool Paused { get; set; }
    public Dictionary<DownloadSource, DownloadRequest> Preferences { get; set; } = [];
    public void Recover()
    {
        foreach (var item in Items.Where(i => i.State == QueueState.Downloading))
        { item.State = QueueState.Interrupted; item.Detail = "Interrompido ao fechar. Você pode tentar novamente."; }
        Paused = Items.Any(i => i.Pending);
    }
    public void Trim()
    {
        var keep = Items.Where(i => !i.Pending).OrderByDescending(i => i.Created).Take(100).Select(i => i.Id).ToHashSet();
        Items.RemoveAll(i => !i.Pending && !keep.Contains(i.Id));
    }
    public static string Key(DownloadRequest request)
    {
        var url = request.Url;
        var identity = url.AbsoluteUri;
        if (PreviewService.IsYouTube(url))
        {
            var id = url.Host == "youtu.be" ? url.AbsolutePath.Trim('/') : url.Query.TrimStart('?').Split('&')
                .FirstOrDefault(x => x.StartsWith("v=", StringComparison.Ordinal))?[2..];
            if (!string.IsNullOrEmpty(id)) identity = "youtube:" + id;
        }
        return $"{identity}\n{request.Source}\n{request.Format}\n{(request.Format == VideoFormat.Mp3 ? "audio" : request.Quality.ToString())}\n{Path.GetFullPath(request.Destination).ToUpperInvariant()}";
    }
    public static IReadOnlyList<DownloadRequest> Batch(string text, DownloadSource source, string destination,
        VideoQuality quality, VideoFormat format, MediaPreview? preview)
    {
        var links = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (links.Length is 0 or > 50) throw new ArgumentException("Cole de 1 a 50 links por vez, um por linha.");
        return links.Select(link =>
        {
            var origin = links.Length == 1 ? source : DownloadInput.IsSpotify(link) ? DownloadSource.Spotify : DownloadSource.Video;
            var url = DownloadInput.Validate(link, origin);
            return new DownloadRequest(url, destination, origin, quality, origin == DownloadSource.Spotify ? VideoFormat.Mp3 : format,
                preview?.OriginalUrl == url && links.Length == 1 ? preview.MatchedUrl : null);
        }).ToArray();
    }
}
public sealed class LibraryStore
{
    private readonly string file;
    public LibraryStore(string? directory = null) => file = Path.Combine(directory ??
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Caeser"), "library.json");
    public DesktopLibrary Load()
    {
        if (!File.Exists(file)) return new();
        var library = JsonSerializer.Deserialize<DesktopLibrary>(File.ReadAllText(file)) ?? new();
        library.Recover(); return library;
    }
    public void Save(DesktopLibrary library)
    {
        library.Trim(); Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temporary = file + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllText(temporary, JsonSerializer.Serialize(library)); File.Move(temporary, file, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
