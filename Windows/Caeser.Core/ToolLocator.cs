namespace Caeser.Core;

public sealed class ToolLocator(string applicationDirectory)
{
    public string ToolsDirectory { get; } = Path.Combine(Path.GetFullPath(applicationDirectory), "Tools");
    public static IReadOnlyList<string> RequiredNames { get; } =
        ["yt-dlp.exe", "ffmpeg.exe", "ffprobe.exe", "deno.exe", "spotdl.exe"];

    public string Tool(string name) => Path.Combine(ToolsDirectory, name);
    public IReadOnlyList<string> Missing(DownloadSource source)
    {
        string[] names = source == DownloadSource.Spotify
            ? ["spotdl.exe", "ffmpeg.exe", "ffprobe.exe", "deno.exe"]
            : ["yt-dlp.exe", "ffmpeg.exe", "ffprobe.exe", "deno.exe"];
        return names.Where(n => !File.Exists(Tool(n))).ToArray();
    }

    public Dictionary<string, string?> EnvironmentVariables()
    {
        var system = System.Environment.GetFolderPath(System.Environment.SpecialFolder.System);
        var windows = System.Environment.GetEnvironmentVariable("SystemRoot") ??
            Path.GetDirectoryName(system) ?? system;
        return new(StringComparer.OrdinalIgnoreCase)
        {
            ["PATH"] = string.Join(Path.PathSeparator, new[] { ToolsDirectory, system, windows }),
            ["PYTHONHOME"] = null, ["PYTHONPATH"] = null, ["VIRTUAL_ENV"] = null,
            ["PYTHONSTARTUP"] = null, ["PYTHONINSPECT"] = null,
            ["SSL_CERT_FILE"] = null, ["SSL_CERT_DIR"] = null,
            ["REQUESTS_CA_BUNDLE"] = null, ["CURL_CA_BUNDLE"] = null,
            ["PYTHONUNBUFFERED"] = "1", ["PYTHONUTF8"] = "1",
            ["DENO_NO_UPDATE_CHECK"] = "1", ["NO_COLOR"] = "1", ["TERM"] = "dumb"
        };
    }
}
