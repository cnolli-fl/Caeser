using System.Text.Json;
using Caeser.Core;
using Xunit;

public sealed class DesktopTests
{
    [Fact] public void TrackingFinalFilesDoesNotSilenceConversionOrProgress()
    {
        var request = new DownloadRequest(new Uri("https://youtube.com/watch?v=test"), Path.GetTempPath(), DownloadSource.Video, Format: VideoFormat.Mp3);
        var args = request.VideoArguments(Path.GetTempPath());
        Assert.Contains("--no-quiet", args);
        Assert.Contains("download:download:%(progress._percent_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s|%(progress._eta)s", args);
        Assert.Contains("after_move:CAESER_FILE:%(filepath)j", args);
    }
    [Fact] public void MixedBatchKeepsSettingsAndPinsOnlyMatchingPreview()
    {
        var spotify = new Uri("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT");
        var match = new Uri("https://youtube.com/watch?v=chosen");
        var preview = new MediaPreview(spotify, "Canção", "Artista", null, 123, MatchedUrl: match);
        var single = DesktopLibrary.Batch(spotify.AbsoluteUri, DownloadSource.Spotify, Path.GetTempPath(), VideoQuality.P480, VideoFormat.Mp4, preview);
        Assert.Equal(match, single[0].MatchedUrl);
        Assert.Contains(match.AbsoluteUri + "|" + spotify.AbsoluteUri, single[0].SpotifyArguments("ffmpeg", "report"));
        var batch = DesktopLibrary.Batch("https://youtube.com/watch?v=one\n" + spotify, DownloadSource.Video, Path.GetTempPath(), VideoQuality.P720, VideoFormat.Mp4, preview);
        Assert.Equal(VideoFormat.Mp4, batch[0].Format); Assert.Equal(VideoFormat.Mp3, batch[1].Format);
        Assert.Null(batch[1].MatchedUrl);
        Assert.Throws<ArgumentException>(() => DesktopLibrary.Batch("https://youtube.com/watch?v=one\n--help", DownloadSource.Video, Path.GetTempPath(), VideoQuality.Best, VideoFormat.Mp3, null));
    }
    [Fact] public void RecoveryDoesNotRestartAndPersistencePreservesHistory()
    {
        var directory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        try
        {
            var request = new DownloadRequest(new Uri("https://youtube.com/watch?v=x"), directory, DownloadSource.Video);
            var library = new DesktopLibrary { Items = [new() { Request = request, State = QueueState.Downloading }, new() { Request = request }] };
            var store = new LibraryStore(directory); store.Save(library);
            var restored = store.Load(); Assert.True(restored.Paused);
            Assert.Equal(QueueState.Interrupted, restored.Items[0].State);
            Assert.Equal(QueueState.Waiting, restored.Items[1].State);
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }
    [Fact] public void SpotifyCollectionsDoNotReuseOneMatchForAllTracks()
    {
        const string json = "[{\"name\":\"Canção\",\"artists\":[\"Artista\"],\"duration\":null,\"download_url\":\"https://youtube.com/watch?v=x\"}]";
        var preview = PreviewService.ParseSpotify(json, new Uri("https://open.spotify.com/album/4cOdK2wGLETKBW3PvgPWqT"));
        Assert.Null(preview.MatchedUrl); Assert.Equal("", preview.DurationText);
        Assert.False(PreviewService.IsYouTube(new Uri("https://youtube.com.evil.test/watch?v=x")));
    }
    [Fact] public void UpdateSelectsOnlyNewestStableWindowsInstaller()
    {
        object Release(string tag, string version, bool prerelease = false) => new {
            tag_name = tag, draft = false, prerelease,
            html_url = $"https://github.com/cnolli-fl/Caeser/releases/tag/{tag}",
            assets = new[] { new { name = $"Caeser-{version}-Windows-x64-Setup.exe", state = "uploaded", size = 123,
                browser_download_url = $"https://github.com/cnolli-fl/Caeser/releases/download/{tag}/Caeser-{version}-Windows-x64-Setup.exe" } }
        };
        var data = JsonSerializer.Serialize(new[] { Release("v9.0.0", "9.0.0"), Release("windows-v2.9.0", "2.9.0"),
            Release("windows-v2.10.0", "2.10.0"), Release("windows-v3.0.0", "3.0.0", true) });
        Assert.Equal("2.10.0", ReleaseUpdates.Parse(data, new Version(2, 0, 0))?.Version);
        Assert.Null(ReleaseUpdates.Parse(data, new Version(2, 10, 0)));
    }
}
