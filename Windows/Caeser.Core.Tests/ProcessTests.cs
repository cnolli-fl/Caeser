using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using Caeser.ProcessProbe;
using Xunit;

namespace Caeser.Core.Tests;

public sealed class ProcessTests
{
    private static string Host => Environment.GetEnvironmentVariable("DOTNET_HOST_PATH") ??
        Path.GetFullPath(Path.Combine(RuntimeEnvironment.GetRuntimeDirectory(), "../../..",
            OperatingSystem.IsWindows() ? "dotnet.exe" : "dotnet"));
    private static string RuntimeConfig => Path.ChangeExtension(typeof(ProcessTests).Assembly.Location, ".runtimeconfig.json");
    private static ProcessCommand Probe(string directory, params string[] args) =>
        new(Host, new[] { "exec", "--runtimeconfig", RuntimeConfig, typeof(ProbeMarker).Assembly.Location }
            .Concat(args).ToArray(), directory);

    [Fact]
    public async Task PassesArgumentsLiterallyWithoutShellInterpretation()
    {
        using var directory = new TemporaryDirectory();
        var marker = Guid.NewGuid().ToString();
        File.WriteAllText(Path.Combine(directory.Path, "identity.txt"), marker);
        string[] arguments = ["música com espaços", "100% {mix}", "& calc.exe", "\"quote\"", "ação 🎵"];
        var lines = new ConcurrentBag<string>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        var result = await new ProcessRunner().RunAsync(Probe(directory.Path, new[] { "echo" }.Concat(arguments).ToArray()), lines.Add, timeout.Token);
        Assert.Equal(0, result.ExitCode);
        using var json = JsonDocument.Parse(Assert.Single(lines));
        Assert.Equal(arguments, json.RootElement.GetProperty("arguments").EnumerateArray().Select(x => x.GetString()));
        // macOS can report /private/var for an input path under the /var symlink.
        var actualDirectory = json.RootElement.GetProperty("directory").GetString()!;
        Assert.Equal(marker, File.ReadAllText(Path.Combine(actualDirectory, "identity.txt")));
    }
    [Fact]
    public async Task DecodesFragmentedUtf8CarriageReturnsAndFinalLine()
    {
        var lines = new ConcurrentBag<string>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        await new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "utf8"), lines.Add, timeout.Token);
        Assert.Contains("ação 🎵 日本語", lines);
        Assert.Contains("progresso 20%", lines);
        Assert.Contains("última linha sem quebra", lines);
        Assert.DoesNotContain(lines, s => s.Contains('\uFFFD'));
    }
    [Fact]
    public async Task DrainsBothPipesWithoutDeadlockAndBoundsLongLines()
    {
        var lines = new ConcurrentBag<string>();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(25));
        await new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "flood"), lines.Add, timeout.Token);
        Assert.Equal(2000, lines.Count(x => x.StartsWith("out:")));
        Assert.Equal(2000, lines.Count(x => x.StartsWith("err:")));
        lines.Clear();
        await new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "long"), lines.Add, timeout.Token);
        Assert.Contains("fim", lines);
        Assert.All(lines, x => Assert.True(x.Length < 17_000));
    }
    [Fact]
    public async Task ReportsExitCode()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        var result = await new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "exit", "7"), _ => { }, timeout.Token);
        Assert.Equal(7, result.ExitCode);
        Assert.False(result.Cancelled);
    }
    [Fact]
    public async Task CancellationStopsTheProcessTree()
    {
        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        var childId = new TaskCompletionSource<int>(TaskCreationOptions.RunContinuationsAsynchronously);
        var run = new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "sleep-tree", RuntimeConfig),
            line => { if (line.StartsWith("child:")) childId.TrySetResult(int.Parse(line[6..])); }, cancellation.Token);
        var id = await childId.Task.WaitAsync(TimeSpan.FromSeconds(15));
        try
        {
            cancellation.Cancel();
            var result = await run.WaitAsync(TimeSpan.FromSeconds(10));
            Assert.True(result.Cancelled);
            Assert.True(await WaitForExit(id));
        }
        finally { KillIfRunning(id); }
    }
    [WindowsFact]
    public async Task WindowsJobClosesOrphanedDescendantsAndTheirPipes()
    {
        var id = 0;
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        try
        {
            var result = await new ProcessRunner().RunAsync(Probe(Path.GetTempPath(), "orphan", RuntimeConfig),
                line => { if (line.StartsWith("child:")) id = int.Parse(line[6..]); }, timeout.Token);
            Assert.Equal(0, result.ExitCode);
            Assert.True(id > 0);
            Assert.True(await WaitForExit(id));
        }
        finally { if (id > 0) KillIfRunning(id); }
    }
    [Fact]
    public async Task AlreadyCancelledTokenDoesNotLaunchAProcess()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => new ProcessRunner().RunAsync(
            Probe(Path.GetTempPath(), "echo", "not launched"), _ => Assert.Fail("Processo indevido"), cancellation.Token));
    }
    private static async Task<bool> WaitForExit(int id)
    {
        try
        {
            using var process = Process.GetProcessById(id);
            await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(5));
            return true;
        }
        catch (ArgumentException) { return true; }
        catch (TimeoutException) { return false; }
    }
    private static void KillIfRunning(int id)
    {
        try { using var process = Process.GetProcessById(id); if (!process.HasExited) process.Kill(true); }
        catch (ArgumentException) { }
    }
}

internal sealed class WindowsFactAttribute : FactAttribute
{
    public WindowsFactAttribute() { if (!OperatingSystem.IsWindows()) Skip = "Requer Job Objects do Windows."; }
}
