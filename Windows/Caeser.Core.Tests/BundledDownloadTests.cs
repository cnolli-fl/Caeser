using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Xunit;

namespace Caeser.Core.Tests;

public sealed class BundledDownloadTests
{
    [BundledToolsFact]
    [Trait("Category", "BundledTools")]
    public async Task DownloadsLocalAudioAndConvertsToMp3UsingOnlyBundledTools()
    {
        var tools = new ToolLocator(Environment.GetEnvironmentVariable("CAESER_TEST_APPLICATION_DIRECTORY")!);
        Assert.Empty(tools.Missing(DownloadSource.Video));
        using var temporary = new TemporaryDirectory();
        var destination = Path.Combine(temporary.Path, "música 100% {mix}");
        Directory.CreateDirectory(destination);
        var original = Path.Combine(temporary.Path, "original.m4a");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        var runner = new ProcessRunner();
        var logs = new ConcurrentQueue<string>();
        var generated = await runner.RunAsync(new(tools.Tool("ffmpeg.exe"),
            ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.4", "-c:a", "aac", original],
            temporary.Path, tools.EnvironmentVariables()), logs.Enqueue, timeout.Token);
        Assert.True(generated.ExitCode == 0, string.Join('\n', logs));
        await using var server = new LocalAudioServer(await File.ReadAllBytesAsync(original));
        // Exercise the exact packaged preview command and its Windows argument
        // forwarding. Generic media intentionally has no thumbnail/uploader.
        var preview = await new PreviewService(tools, runner).FetchAsync(server.Url, DownloadSource.Video, timeout.Token);
        Assert.False(string.IsNullOrWhiteSpace(preview.Title));
        Assert.Null(preview.Artwork);
        var request = new DownloadRequest(server.Url, destination, DownloadSource.Video, Format: VideoFormat.Mp3);
        var result = await new DownloadSession(tools, runner).RunAsync(request, logs.Enqueue, timeout.Token);
        Assert.True(result.Succeeded, result.Error + "\n" + string.Join('\n', logs));
        var downloaded = Assert.Single(Directory.GetFiles(destination, "*.mp3"));
        Assert.True(new FileInfo(downloaded).Length > 1000);
        Assert.Contains(logs, line => line.Contains("[ExtractAudio]"));
        var probe = new ConcurrentQueue<string>();
        var inspected = await runner.RunAsync(new(tools.Tool("ffprobe.exe"),
            ["-v", "error", "-show_entries", "stream=codec_name", "-of", "json", downloaded],
            destination, tools.EnvironmentVariables()), probe.Enqueue, timeout.Token);
        Assert.Equal(0, inspected.ExitCode);
        using var json = JsonDocument.Parse(string.Join('\n', probe));
        Assert.Equal("mp3", json.RootElement.GetProperty("streams")[0].GetProperty("codec_name").GetString());
    }

    // An original tone served only on loopback: no music rights, account or external service involved.
    private sealed class LocalAudioServer : IAsyncDisposable
    {
        private readonly TcpListener listener = new(IPAddress.Loopback, 0);
        private readonly CancellationTokenSource stop = new();
        private readonly byte[] audio;
        private readonly Task serving;
        public Uri Url { get; }
        public LocalAudioServer(byte[] audio)
        {
            this.audio = audio;
            listener.Start();
            Url = new Uri($"http://127.0.0.1:{((IPEndPoint)listener.LocalEndpoint).Port}/tone.m4a");
            serving = ServeAsync();
        }
        private async Task ServeAsync()
        {
            while (!stop.IsCancellationRequested)
            {
                using var client = await listener.AcceptTcpClientAsync(stop.Token);
                try
                {
                    using var stream = client.GetStream();
                    using var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, leaveOpen: true);
                    var request = await reader.ReadLineAsync(stop.Token) ?? "";
                    var remaining = 16384 - request.Length;
                    while (await reader.ReadLineAsync(stop.Token) is { Length: > 0 } header)
                        if ((remaining -= header.Length) < 0) throw new IOException("Cabeçalhos excessivos no teste local.");
                    var response = Encoding.ASCII.GetBytes($"HTTP/1.1 200 OK\r\nContent-Type: audio/mp4\r\nContent-Length: {audio.Length}\r\nConnection: close\r\n\r\n");
                    await stream.WriteAsync(response, stop.Token);
                    if (!request.StartsWith("HEAD ", StringComparison.Ordinal))
                        await stream.WriteAsync(audio, stop.Token);
                }
                catch (IOException) { /* A downloader may close its format-probing request early. */ }
            }
        }
        public async ValueTask DisposeAsync()
        {
            stop.Cancel();
            listener.Stop();
            try { await serving; }
            catch (OperationCanceledException) { }
            catch (SocketException) when (stop.IsCancellationRequested) { }
            stop.Dispose();
        }
    }
}

internal sealed class BundledToolsFactAttribute : FactAttribute
{
    public BundledToolsFactAttribute()
    {
        if (!OperatingSystem.IsWindows() || string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("CAESER_TEST_APPLICATION_DIRECTORY")))
            Skip = "Executado no Windows após construir o pacote completo de ferramentas.";
    }
}
