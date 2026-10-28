using System.Security.Cryptography;
using Xunit;

namespace Caeser.Core.Tests;

public sealed class DownloadTests
{
    private const string Track = "4cOdK2wGLETKBW3PvgPWqT";
    [Theory]
    [InlineData("https://www.youtube.com/watch?v=abc")]
    [InlineData("http://example.com/video?id=1&x=2")]
    public void VideoAcceptsCompleteLinks(string url) =>
        Assert.Equal(url, DownloadInput.Validate(url, DownloadSource.Video).AbsoluteUri);

    [Theory]
    [InlineData("")]
    [InlineData("youtube.com/watch?v=abc")]
    [InlineData("file:///C:/Windows/explorer.exe")]
    [InlineData("https://user:password@example.com/video")]
    [InlineData("--exec calc.exe")]
    public void VideoRejectsInvalidInput(string input) =>
        Assert.Throws<ArgumentException>(() => DownloadInput.Validate(input, DownloadSource.Video));

    [Theory]
    [InlineData("track")]
    [InlineData("album")]
    [InlineData("playlist")]
    public void SpotifyNormalizesPublicLinksAndUris(string type)
    {
        var expected = $"https://open.spotify.com/{type}/{Track}";
        Assert.Equal(expected, DownloadInput.Validate($"spotify:{type}:{Track}", DownloadSource.Spotify).AbsoluteUri);
        Assert.Equal(expected, DownloadInput.Validate($"https://open.spotify.com/intl-pt/{type}/{Track}?si=secret", DownloadSource.Spotify).AbsoluteUri);
    }
    [Theory]
    [InlineData("https://spotify.link/abc")]
    [InlineData("https://open.spotify.com.evil.test/track/4cOdK2wGLETKBW3PvgPWqT")]
    [InlineData("https://open.spotify.com/artist/4cOdK2wGLETKBW3PvgPWqT")]
    [InlineData("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT/extra")]
    [InlineData("https://open.spotify.com/track/éééééééééééééééééééééé")]
    [InlineData("spotify:track:short")]
    [InlineData("https://open.spotify.com:9999/track/4cOdK2wGLETKBW3PvgPWqT")]
    public void SpotifyRejectsUnsupportedLinks(string input) =>
        Assert.Throws<ArgumentException>(() => DownloadInput.Validate(input, DownloadSource.Spotify));

    [Fact]
    public void SpotifyIsNotPassedToVideoDownloader() =>
        Assert.Throws<ArgumentException>(() => DownloadInput.Validate($"spotify:track:{Track}", DownloadSource.Video));

    [Fact]
    public void EveryVideoFallbackHonorsTheQualityCeiling()
    {
        foreach (var quality in Enum.GetValues<VideoQuality>().Where(x => x != VideoQuality.Best))
        foreach (var format in new[] { VideoFormat.Automatic, VideoFormat.Mp4, VideoFormat.WebM })
        {
            var request = new DownloadRequest(new("https://example.com"), Path.GetTempPath(), DownloadSource.Video, quality, format);
            Assert.All(request.FormatSelector().Split('/'), branch => Assert.Contains("[height<=", branch));
        }
    }
    [Fact]
    public void Mp3UsesBestAudioAndMaximumVbrQuality()
    {
        var request = new DownloadRequest(new("https://example.com"), Path.GetTempPath(), DownloadSource.Video, VideoQuality.P480, VideoFormat.Mp3);
        var args = request.VideoArguments(Path.GetTempPath()).ToList();
        Assert.Equal("bestaudio/best", request.FormatSelector());
        Assert.Equal("0", args[args.IndexOf("--audio-quality") + 1]);
        Assert.Contains("--windows-filenames", args);
        Assert.Equal("--", args[^2]);
    }
    [Fact]
    public void PathsRemainSingleArgumentsAndSpotifyDoesNotDownloadFromSpotify()
    {
        var folder = Path.Combine(Path.GetTempPath(), "minhas músicas {mix} 100%");
        var request = new DownloadRequest(new($"https://open.spotify.com/track/{Track}"), folder, DownloadSource.Spotify);
        var args = request.SpotifyArguments(Path.Combine(folder, "ffmpeg.exe"), Path.Combine(folder, "error report.txt")).ToList();
        Assert.Equal("youtube", args[args.IndexOf("--audio") + 1]);
        Assert.Equal("youtube-music", args[args.IndexOf("--audio") + 2]);
        Assert.Equal("0", args[args.IndexOf("--bitrate") + 1]);
        Assert.Equal("{artists} - {title} [{track-id}].{output-ext}", args[args.IndexOf("--output") + 1]);
        Assert.DoesNotContain(folder, args[args.IndexOf("--output") + 1]);
    }
    [Fact]
    public void ProgressParsesPercentCultureAndConversion()
    {
        var progress = new DownloadProgress();
        progress.Receive("\x1b[32mdownload: 12,5%|10MiB|80MiB|2MiB/s|35\x1b[0m", DownloadSource.Video);
        Assert.Equal(0.125, progress.Fraction);
        Assert.Equal("2MiB/s", progress.Speed);
        Assert.Contains("35", progress.Eta);
        progress.Receive("[Merger] Merging formats", DownloadSource.Video);
        Assert.Null(progress.Fraction);
        Assert.Contains("Unindo", progress.Status);
        progress.Receive("download:NaN|N/A|N/A|N/A|N/A", DownloadSource.Video);
        Assert.Null(progress.Fraction);
    }
    [Fact]
    public void SpotifyPartialFailuresAreErrorsEvenWithExitZeroAndEmptyReport()
    {
        var progress = new DownloadProgress();
        progress.Receive("SPOTDL|INFO|1/2 complete", DownloadSource.Spotify);
        progress.Receive("SPOTDL|ERROR|A segunda música falhou", DownloadSource.Spotify);
        Assert.Equal(0.5, progress.Fraction);
        Assert.Equal("A segunda música falhou", progress.CompletionError(0, DownloadSource.Spotify, ""));
    }
    [Fact]
    public void SpotifyMustProcessAtLeastOneTrack()
    {
        var progress = new DownloadProgress();
        Assert.NotNull(progress.CompletionError(0, DownloadSource.Spotify, ""));
        progress.Receive("SPOTDL|INFO|1/1 complete", DownloadSource.Spotify);
        Assert.Null(progress.CompletionError(0, DownloadSource.Spotify, ""));
        Assert.NotNull(progress.CompletionError(0, DownloadSource.Spotify, "uma música falhou"));
    }
    [Fact]
    public void ToolsNeverFallBackToAnUnrelatedSystemInstallation()
    {
        using var dir = new TemporaryDirectory();
        var tools = new ToolLocator(dir.Path);
        Assert.Contains("yt-dlp.exe", tools.Missing(DownloadSource.Video));
        Assert.DoesNotContain("spotdl.exe", tools.Missing(DownloadSource.Video));
        Assert.Contains("spotdl.exe", tools.Missing(DownloadSource.Spotify));
        Assert.False(tools.EnvironmentVariables()["PATH"]!.Contains("homebrew", StringComparison.OrdinalIgnoreCase));
        Assert.Null(tools.EnvironmentVariables()["PYTHONPATH"]);
    }
    [Fact]
    public void SettingsSurviveUnicodePathsAndCorruption()
    {
        using var dir = new TemporaryDirectory();
        var store = new SettingsStore(dir.Path);
        var destination = Path.Combine(dir.Path, "Músicas e vídeos");
        store.SaveDestination(destination);
        Assert.Equal(destination, store.LoadDestination());
        File.WriteAllText(Path.Combine(dir.Path, "settings.json"), "{broken");
        Assert.Null(store.LoadDestination());
        Assert.Throws<ArgumentException>(() => store.SaveDestination("relative"));
    }
    [Fact]
    public void WindowsUsesApprovedOceanLogoWithIndependentSourceAssets()
    {
        var root = RepositoryRoot();
        var logo = File.ReadAllBytes(Path.Combine(root, "Windows/BrandSources/Ocean/CaeserLogo.png"));
        Assert.Equal("A3A7FFADCEAE2F45C4507E885454328792FC48673C96280E1E38B96ED8F5E1CE",
            Convert.ToHexString(SHA256.HashData(logo)));
        var project = File.ReadAllText(Path.Combine(root, "Windows/Caeser.App/Caeser.App.csproj"));
        Assert.Contains(@"..\BrandSources\Ocean\CaeserLogo.png", project);
        Assert.DoesNotContain(@"Sources\VideoDownloader\Resources\CaeserLogo.png", project);
        var iconScript = File.ReadAllText(Path.Combine(root, "Windows/Scripts/PrepareAssets.mjs"));
        Assert.Contains("Windows/BrandSources/Ocean/AppIcon.iconset", iconScript);
        Assert.DoesNotContain("Assets.xcassets/AppIcon.appiconset", iconScript);
        Assert.Contains("YouTubeMark.scale-300.png", project);
        Assert.Contains("SpotifyMark.scale-300.png", project);
    }
    [Fact]
    public void SelectorDoesNotReferenceTheInvalidHoverBrushThatCrashedOnMouseInput()
    {
        var xaml = File.ReadAllText(Path.Combine(RepositoryRoot(), "Windows/Caeser.App/Controls/SourceSelector.xaml"));
        Assert.DoesNotContain("ControlSubtleFillColorSecondaryBrush", xaml);
        Assert.Contains("{ThemeResource SubtleFillColorSecondaryBrush}", xaml);
    }
    internal static string RepositoryRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CaeserIconOriginal.png"))) dir = dir.Parent;
        return dir?.FullName ?? throw new DirectoryNotFoundException("Repositório não encontrado.");
    }
}

internal sealed class TemporaryDirectory : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"Caeser-tests-{Guid.NewGuid():N}");
    public TemporaryDirectory() => Directory.CreateDirectory(Path);
    public void Dispose() => Directory.Delete(Path, recursive: true);
}
