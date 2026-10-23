using System.Net;
using System.Text.Json;
using Caeser.Core;
using Xunit;

public sealed class PreviewTests
{
    private static readonly ToolLocator Tools = new(Path.GetTempPath());
    private static readonly Uri Video = new("https://www.youtube.com/watch?v=metadata-test");
    private static readonly Uri Spotify = new("https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT");
    private const string PublicJson = "{\"title\":\"Canção com ç e \\\"aspas\\\"\",\"author_name\":\"Artista\",\"thumbnail_url\":\"https://example.invalid/capa.jpg\"}";

    [Fact] public async Task ShowsPublicMetadataBeforeSlowOrUnavailableExtractor()
    {
        var shown = new List<MediaPreview>();
        using var http = new HttpClient(new Handler(PublicJson));
        var runner = new Runner((command, output, token) => {
            Assert.Single(shown);
            Assert.Contains("--output-na-placeholder", command.Arguments);
            Assert.Contains("null", command.Arguments);
            Assert.Contains("--ignore-no-formats-error", command.Arguments);
            return Task.FromResult(new ProcessResult(1, false));
        });
        var value = await new PreviewService(Tools, runner, http).FetchAsync(Video, DownloadSource.Video,
            CancellationToken.None, new PreviewProgress(shown.Add));
        Assert.Equal("Canção com ç e \"aspas\"", value.Title);
        Assert.Equal("Artista", value.Creator);
        Assert.Null(value.Duration);
        Assert.Equal("https://example.invalid/capa.jpg", value.Artwork);
    }

    [Fact] public async Task NullFieldsAndQuotedTitlesRemainValidWithoutPublicMetadata()
    {
        using var http = new HttpClient(new Handler("", HttpStatusCode.ServiceUnavailable));
        var runner = new Runner((command, output, token) => {
            output(JsonSerializer.Serialize(new { title = "Título \"especial\" 100%", creator = (string?)null,
                thumbnail = (string?)null, duration = (double?)null }));
            return Task.FromResult(new ProcessResult(0, false));
        });
        var value = await new PreviewService(Tools, runner, http).FetchAsync(Video, DownloadSource.Video, CancellationToken.None);
        Assert.Equal("Título \"especial\" 100%", value.Title);
        Assert.Null(value.Artwork);
        Assert.Equal("", value.DurationText);
    }

    [Fact] public async Task SpotifyPublicPreviewDoesNotInventYouTubeMatch()
    {
        using var http = new HttpClient(new Handler(PublicJson));
        var runner = new Runner((command, output, token) => Task.FromResult(new ProcessResult(1, false)));
        var value = await new PreviewService(Tools, runner, http).FetchAsync(Spotify, DownloadSource.Spotify, CancellationToken.None);
        Assert.Equal(Spotify, value.OriginalUrl);
        Assert.Null(value.MatchedUrl);
        Assert.Equal("Canção com ç e \"aspas\"", value.Title);
    }

    [Fact] public async Task CancellingAfterFirstPreviewDoesNotReturnStaleMetadata()
    {
        using var cancellation = new CancellationTokenSource();
        using var http = new HttpClient(new Handler(PublicJson));
        var runner = new Runner((command, output, token) => {
            cancellation.Cancel(); token.ThrowIfCancellationRequested();
            return Task.FromResult(new ProcessResult(0, false));
        });
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            new PreviewService(Tools, runner, http).FetchAsync(Video, DownloadSource.Video, cancellation.Token));
    }

    [Fact] public async Task UntrustedArtworkIsNotLoaded()
    {
        using var http = new HttpClient(new Handler("{\"title\":\"Teste\",\"thumbnail_url\":\"file:///C:/segredo.txt\"}"));
        var runner = new Runner((command, output, token) => Task.FromResult(new ProcessResult(1, false)));
        var value = await new PreviewService(Tools, runner, http).FetchAsync(Video, DownloadSource.Video, CancellationToken.None);
        Assert.Null(value.Artwork);
    }

    [Fact] public async Task EnrichmentKeepsPublicCoverAndAddsDuration()
    {
        using var http = new HttpClient(new Handler(PublicJson));
        var runner = new Runner((command, output, token) => {
            output("{\"title\":\"Canção\",\"creator\":\"Artista\",\"thumbnail\":\"https://example.invalid/alternate.webp\",\"duration\":183}");
            return Task.FromResult(new ProcessResult(0, false));
        });
        var value = await new PreviewService(Tools, runner, http).FetchAsync(Video, DownloadSource.Video, CancellationToken.None);
        Assert.Equal("https://example.invalid/capa.jpg", value.Artwork);
        Assert.Equal("3:03", value.DurationText);
    }

    private sealed class PreviewProgress(Action<MediaPreview> action) : IProgress<MediaPreview>
    { public void Report(MediaPreview value) => action(value); }
    private sealed class Runner(Func<ProcessCommand, Action<string>, CancellationToken, Task<ProcessResult>> action) : IProcessRunner
    { public Task<ProcessResult> RunAsync(ProcessCommand command, Action<string> output, CancellationToken token) => action(command, output, token); }
    private sealed class Handler(string json, HttpStatusCode status = HttpStatusCode.OK) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
        {
            Assert.Equal("https", request.RequestUri!.Scheme);
            Assert.Contains(request.RequestUri.Host, new[] { "www.youtube.com", "open.spotify.com" });
            Assert.Equal("/oembed", request.RequestUri.AbsolutePath);
            Assert.Empty(request.Headers.Authorization?.ToString() ?? "");
            return Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(json) });
        }
    }
}
