using System.Text.RegularExpressions;

namespace Caeser.Core;

public enum DownloadSource { Video, Spotify }
public enum VideoFormat { Automatic, Mp4, WebM, Mp3 }
public enum VideoQuality { Best, P2160, P1440, P1080, P720, P480 }

public static partial class DownloadInput
{
    public static bool IsSpotify(string text) =>
        text.Trim().StartsWith("spotify:", StringComparison.OrdinalIgnoreCase) ||
        (Uri.TryCreate(text.Trim(), UriKind.Absolute, out var uri) &&
         uri.Host.Equals("open.spotify.com", StringComparison.OrdinalIgnoreCase));

    public static Uri Validate(string text, DownloadSource source)
    {
        var value = text.Trim();
        if (value.StartsWith("spotify:", StringComparison.OrdinalIgnoreCase))
        {
            var parts = value.Split(':');
            if (parts.Length != 3) throw new ArgumentException(SpotifyError);
            value = $"https://open.spotify.com/{parts[1]}/{parts[2]}";
        }
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
            (uri.Scheme != "https" && uri.Scheme != "http") ||
            string.IsNullOrEmpty(uri.Host) || !string.IsNullOrEmpty(uri.UserInfo))
            throw new ArgumentException("Cole um link completo começando com https://.");

        if (source == DownloadSource.Video)
        {
            if (IsSpotify(value))
                throw new ArgumentException("Selecione Spotify para buscar esta música no YouTube.");
            return uri;
        }
        if (!uri.Host.Equals("open.spotify.com", StringComparison.OrdinalIgnoreCase) ||
            !uri.IsDefaultPort)
            throw new ArgumentException(SpotifyError);
        var segments = uri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length > 0 && segments[0].StartsWith("intl-", StringComparison.Ordinal))
            segments = segments[1..];
        if (segments.Length != 2 ||
            segments[0] is not ("track" or "album" or "playlist") ||
            !SpotifyId().IsMatch(segments[1]))
            throw new ArgumentException(SpotifyError);
        return new Uri($"https://open.spotify.com/{segments[0]}/{segments[1]}");
    }

    private const string SpotifyError =
        "Cole um link público de música, álbum ou playlist de open.spotify.com. Links privados e links curtos não são suportados.";
    [GeneratedRegex("^[A-Za-z0-9]{22}$", RegexOptions.CultureInvariant)]
    private static partial Regex SpotifyId();
}

public sealed record DownloadRequest(
    Uri Url, string Destination, DownloadSource Source,
    VideoQuality Quality = VideoQuality.Best, VideoFormat Format = VideoFormat.Automatic)
{
    public IReadOnlyList<string> VideoArguments(string toolsDirectory)
    {
        var args = new List<string>
        {
            "--ignore-config", "--newline", "--progress", "--no-playlist",
            "--windows-filenames",
            "--ffmpeg-location", toolsDirectory,
            "--js-runtimes", $"deno:{Path.Combine(toolsDirectory, "deno.exe")}",
            "--paths", Destination, "-o", "%(title)s.%(ext)s",
            "--progress-template",
            "download:%(progress._percent_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s|%(progress._eta)s",
            "-f", FormatSelector()
        };
        switch (Format)
        {
            case VideoFormat.Mp4: args.AddRange(["--merge-output-format", "mp4"]); break;
            case VideoFormat.WebM: args.AddRange(["--merge-output-format", "webm"]); break;
            case VideoFormat.Mp3: args.AddRange(["-x", "--audio-format", "mp3", "--audio-quality", "0"]); break;
        }
        args.AddRange(["--", Url.AbsoluteUri]);
        return args;
    }

    public IReadOnlyList<string> SpotifyArguments(string ffmpeg, string errorReport) =>
    [
        "download", Url.AbsoluteUri,
        "--audio", "youtube", "youtube-music",
        "--format", "mp3", "--bitrate", "0",
        "--ffmpeg", ffmpeg,
        "--output", "{artists} - {title} [{track-id}].{output-ext}",
        "--threads", "1", "--overwrite", "skip",
        "--simple-tui", "--headless", "--max-retries", "2",
        "--log-level", "INFO", "--log-format", "SPOTDL|%(levelname)s|%(message)s",
        "--save-errors", errorReport, "--lyrics"
    ];

    public string FormatSelector()
    {
        int? height = Quality switch
        {
            VideoQuality.P2160 => 2160, VideoQuality.P1440 => 1440,
            VideoQuality.P1080 => 1080, VideoQuality.P720 => 720,
            VideoQuality.P480 => 480, _ => null
        };
        var h = height.HasValue ? $"[height<={height}]" : "";
        return Format switch
        {
            VideoFormat.Mp3 => "bestaudio/best",
            VideoFormat.Mp4 =>
                $"bv*{h}[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/bv*{h}[ext=mp4]+ba[ext=m4a]/b{h}[ext=mp4]/b{h}",
            VideoFormat.WebM => $"bv*{h}[ext=webm]+ba[ext=webm]/bv*{h}+ba/b{h}",
            _ => $"bv*{h}+ba/b{h}"
        };
    }
}
