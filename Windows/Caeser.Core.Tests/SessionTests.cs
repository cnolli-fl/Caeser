using Xunit;

namespace Caeser.Core.Tests;

public sealed class SessionTests
{
    [Fact]
    public async Task IncompleteBundleNeverLaunchesAnExternalTool()
    {
        using var directory = new TemporaryDirectory();
        var session = new DownloadSession(new ToolLocator(directory.Path), new FakeRunner(_ => throw new Exception("Não deve executar")));
        var result = await session.RunAsync(Request(directory.Path), _ => { }, CancellationToken.None);
        Assert.False(result.Succeeded);
        Assert.Contains("Pacote incompleto", result.Error);
    }
    [Fact]
    public async Task AReportFailureIsNotSuccessEvenWhenSpotdlExitsZero()
    {
        using var directory = new TemporaryDirectory();
        var tools = PrepareTools(directory.Path);
        var runner = new FakeRunner(command =>
        {
            var args = command.Arguments.ToList();
            File.WriteAllText(args[args.IndexOf("--save-errors") + 1], "Música indisponível");
            return new(0, false);
        }, ["SPOTDL|INFO|1/2 complete"]);
        var result = await new DownloadSession(tools, runner).RunAsync(Request(directory.Path, DownloadSource.Spotify), _ => { }, CancellationToken.None);
        Assert.False(result.Succeeded);
        Assert.Equal("Música indisponível", result.Error);
        Assert.True(Directory.Exists(directory.Path)); // Never remove the download destination.
    }
    [Fact]
    public async Task SpotifySuccessRequiresProcessedTracks()
    {
        using var directory = new TemporaryDirectory();
        var tools = PrepareTools(directory.Path);
        var result = await new DownloadSession(tools, new FakeRunner(_ => new(0, false), ["SPOTDL|INFO|1/1 complete"]))
            .RunAsync(Request(directory.Path, DownloadSource.Spotify), _ => { }, CancellationToken.None);
        Assert.True(result.Succeeded);
    }
    [Fact]
    public async Task CancellationPreservesFilesInTheDestination()
    {
        using var directory = new TemporaryDirectory();
        var tools = PrepareTools(directory.Path);
        var saved = Path.Combine(directory.Path, "minha música.mp3");
        File.WriteAllText(saved, "já salvo");
        var result = await new DownloadSession(tools, new FakeRunner(_ => new(1, true)))
            .RunAsync(Request(directory.Path), _ => { }, CancellationToken.None);
        Assert.True(result.Cancelled);
        Assert.Equal("já salvo", File.ReadAllText(saved));
    }
    private static DownloadRequest Request(string destination, DownloadSource source = DownloadSource.Video) =>
        new(new Uri(source == DownloadSource.Spotify ?
            "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT" : "https://www.youtube.com/watch?v=example"), destination, source);
    private static ToolLocator PrepareTools(string directory)
    {
        var tools = new ToolLocator(directory);
        Directory.CreateDirectory(tools.ToolsDirectory);
        foreach (var name in ToolLocator.RequiredNames) File.WriteAllText(tools.Tool(name), "fixture");
        return tools;
    }
    private sealed class FakeRunner(Func<ProcessCommand, ProcessResult> run, string[]? lines = null) : IProcessRunner
    {
        public Task<ProcessResult> RunAsync(ProcessCommand command, Action<string> output, CancellationToken cancellationToken)
        {
            foreach (var line in lines ?? []) output(line);
            return Task.FromResult(run(command));
        }
    }
}
