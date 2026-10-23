using System.Text.Json;

namespace Caeser.Core;

public sealed class PreviewService(ToolLocator tools, IProcessRunner runner, HttpClient? http = null)
{
    private static readonly HttpClient PublicMetadata = new(new HttpClientHandler { AllowAutoRedirect = false });
    public static bool IsYouTube(Uri? url) => url is { Scheme: "https", UserInfo: "" } &&
        new[] { "youtube.com", "www.youtube.com", "music.youtube.com", "m.youtube.com", "youtu.be" }.Contains(url.Host);
    private static string? String(JsonElement item, string key) => item.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static double? Number(JsonElement item, string key) => item.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) ? number : null;
    private static string? Image(string? value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == "https" && uri.UserInfo == "" ? value : null;
    public async Task<MediaPreview> FetchAsync(Uri url, DownloadSource source, CancellationToken cancellationToken,
        IProgress<MediaPreview>? progress = null)
    {
        var basic = await PublicPreviewAsync(url, source, cancellationToken).ConfigureAwait(false);
        if (basic != null) progress?.Report(basic);
        try
        {
            var detailed = await FullPreviewAsync(url, source, cancellationToken).ConfigureAwait(false);
            // Keep the public poster already shown instead of swapping to a
            // different extractor thumbnail/codec while details are enriched.
            return basic?.Artwork is { } poster ? detailed with { Artwork = poster } : detailed;
        }
        catch (Exception e) when (basic != null && !cancellationToken.IsCancellationRequested &&
            e is IOException or JsonException or OperationCanceledException or System.ComponentModel.Win32Exception)
        { return basic; }
    }
    private async Task<MediaPreview?> PublicPreviewAsync(Uri url, DownloadSource source, CancellationToken cancellationToken)
    {
        var spotify = source == DownloadSource.Spotify && url is { Scheme: "https", Host: "open.spotify.com", UserInfo: "" };
        if (!spotify && !IsYouTube(url)) return null;
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(7));
        try
        {
            var endpoint = (spotify ? "https://open.spotify.com/oembed?url=" : "https://www.youtube.com/oembed?format=json&url=") + Uri.EscapeDataString(url.AbsoluteUri);
            using var response = await (http ?? PublicMetadata).GetAsync(endpoint, HttpCompletionOption.ResponseHeadersRead, timeout.Token).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token).ConfigureAwait(false);
            var bytes = new byte[128001];
            var count = await stream.ReadAtLeastAsync(bytes, bytes.Length, false, timeout.Token).ConfigureAwait(false);
            if (count > 128000) throw new IOException("Resposta de prévia muito grande.");
            using var document = JsonDocument.Parse(bytes.AsMemory(0, count));
            var item = document.RootElement;
            if (item.ValueKind != JsonValueKind.Object) return null;
            var title = String(item, "title");
            if (string.IsNullOrWhiteSpace(title)) return null;
            return new(url, title, String(item, "author_name") ?? (spotify ? "Spotify" : "YouTube"),
                Image(String(item, "thumbnail_url")), null);
        }
        catch (Exception e) when (e is HttpRequestException or IOException or JsonException or OperationCanceledException)
        { cancellationToken.ThrowIfCancellationRequested(); return null; }
    }
    private async Task<MediaPreview> FullPreviewAsync(Uri url, DownloadSource source, CancellationToken cancellationToken)
    {
        if (source == DownloadSource.Video) return await VideoAsync(url, cancellationToken).ConfigureAwait(false);
        var temporary = Path.Combine(Path.GetTempPath(), "Caeser-preview-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temporary);
        try
        {
            var file = Path.Combine(temporary, "preview.spotdl");
            List<string> args = ["save", url.AbsoluteUri, "--save-file", file, "--audio", "youtube", "youtube-music",
                "--ffmpeg", tools.Tool("ffmpeg.exe"), "--threads", "1", "--headless", "--simple-tui", "--log-level", "ERROR",
                "--max-retries", "1", "--lyrics"];
            if (url.AbsolutePath.Contains("/track/")) args.Add("--preload");
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(120));
            var result = await runner.RunAsync(new(tools.Tool("spotdl.exe"), args, temporary, tools.EnvironmentVariables()), _ => { }, timeout.Token).ConfigureAwait(false);
            timeout.Token.ThrowIfCancellationRequested();
            if (result.ExitCode != 0 || !File.Exists(file) || new FileInfo(file).Length > 8_000_000) throw new IOException("Prévia indisponível.");
            var preview = ParseSpotify(await File.ReadAllTextAsync(file, cancellationToken).ConfigureAwait(false), url);
            if (preview.MatchedUrl != null)
            {
                try { var match = await VideoAsync(preview.MatchedUrl, cancellationToken).ConfigureAwait(false); preview = preview with { MatchTitle = $"{match.Title} · {match.Creator} · {match.DurationText}" }; }
                catch (Exception e) when (e is IOException or JsonException or OperationCanceledException) { cancellationToken.ThrowIfCancellationRequested(); }
            }
            return preview;
        }
        finally { try { Directory.Delete(temporary, true); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
    }
    public static MediaPreview ParseSpotify(string text, Uri url)
    {
        using var document = JsonDocument.Parse(text);
        var songs = document.RootElement.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.Object).ToArray();
        if (songs.Length == 0) throw new IOException("Não foi encontrada uma correspondência.");
        var first = songs[0]; var collection = !url.AbsolutePath.Contains("/track/");
        var match = Uri.TryCreate(String(first, "download_url"), UriKind.Absolute, out var candidate) && IsYouTube(candidate) && !collection ? candidate : null;
        var artists = first.TryGetProperty("artists", out var values) ? string.Join(", ", values.EnumerateArray().Select(x => x.GetString())) : "Spotify";
        return new(url, collection ? String(first, "list_name") ?? String(first, "album_name") ?? "Coleção Spotify" : String(first, "name") ?? "Música",
            collection ? $"{songs.Length} músicas · Spotify" : artists, Image(String(first, "cover_url")),
            songs.Sum(x => Number(x, "duration") ?? 0), songs.Length, match);
    }
    private async Task<MediaPreview> VideoAsync(Uri url, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(60));
        string? json = null; var gate = new object();
        var result = await runner.RunAsync(new(tools.Tool("yt-dlp.exe"),
            ["--ignore-config", "--no-playlist", "--skip-download", "--no-warnings", "--socket-timeout", "15", "--retries", "1",
             "--ignore-no-formats-error", "--output-na-placeholder", "null",
             "--js-runtimes", $"deno:{tools.Tool("deno.exe")}", "--print",
             "{\"title\":%(title)j,\"creator\":%(uploader)j,\"thumbnail\":%(thumbnail)j,\"duration\":%(duration)j}", "--", url.AbsoluteUri],
            Path.GetTempPath(), tools.EnvironmentVariables()), line => { if (line.StartsWith('{')) lock (gate) json = line; }, timeout.Token).ConfigureAwait(false);
        timeout.Token.ThrowIfCancellationRequested();
        if (result.ExitCode != 0 || json == null) throw new IOException("Prévia indisponível.");
        using var document = JsonDocument.Parse(json);
        var item = document.RootElement;
        return new(url, String(item, "title") ?? "Vídeo", String(item, "creator") ?? "", Image(String(item, "thumbnail")), Number(item, "duration"));
    }
}
