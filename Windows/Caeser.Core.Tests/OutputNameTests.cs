using System.Text.Json;
using Xunit;
namespace Caeser.Core.Tests;

public sealed class OutputNameTests
{
    [Fact]
    public void LiteralNamesSurviveQueueAndBecomeOutputTemplates()
    {
        var name = OutputName.Validate("  Minha música 100%.MP3 ");
        Assert.Equal("Minha música 100%", name);
        var request = new DownloadRequest(new Uri("https://youtu.be/example"), "C:\\Downloads",
            DownloadSource.Video, Format: VideoFormat.Mp3, FileName: name);
        Assert.Equal(name, JsonSerializer.Deserialize<DownloadRequest>(JsonSerializer.Serialize(request))!.FileName);
        var args = request.VideoArguments("C:\\Tools").ToList();
        Assert.Equal("Minha música 100%%.%(ext)s", args[args.IndexOf("-o") + 1]);
        Assert.NotEqual(DesktopLibrary.Key(request), DesktopLibrary.Key(request with { FileName = "Outro" }));
        var legacy = new DownloadRequest(request.Url, request.Destination, request.Source);
        Assert.Null(JsonSerializer.Deserialize<DownloadRequest>(JsonSerializer.Serialize(legacy))!.FileName);
        var spotify = request with { Source = DownloadSource.Spotify };
        var spotArgs = spotify.SpotifyArguments("ffmpeg", "errors").ToList();
        Assert.Equal("Minha música 100%.{output-ext}", spotArgs[spotArgs.IndexOf("--output") + 1]);
    }

    [Theory]
    [InlineData("../arquivo")]
    [InlineData("CON")]
    [InlineData("aux.mp3")]
    [InlineData("{title}")]
    [InlineData("a\\b")]
    [InlineData(".mp4")]
    public void UnsafeNamesAreRejected(string value) =>
        Assert.Throws<ArgumentException>(() => OutputName.Validate(value));

    [Fact]
    public void OneNameCannotCollapseMultipleOutputs()
    {
        Assert.Throws<ArgumentException>(() => DesktopLibrary.Batch(
            "https://youtu.be/a https://youtu.be/b", DownloadSource.Video, "C:\\Downloads",
            VideoQuality.Best, VideoFormat.Mp4, null, "Mesmo nome"));
        Assert.Throws<ArgumentException>(() => DesktopLibrary.Batch(
            "https://open.spotify.com/album/4cOdK2wGLETKBW3PvgPWqT", DownloadSource.Spotify, "C:\\Downloads",
            VideoQuality.Best, VideoFormat.Mp3, null, "Mesmo nome"));
    }
}
