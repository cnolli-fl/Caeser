using System.Diagnostics;
using System.Text;

namespace Caeser.Core;

public sealed record ProcessCommand(
    string Executable, IReadOnlyList<string> Arguments, string WorkingDirectory,
    IReadOnlyDictionary<string, string?>? Environment = null);
public sealed record ProcessResult(int ExitCode, bool Cancelled);

public interface IProcessRunner
{
    Task<ProcessResult> RunAsync(ProcessCommand command, Action<string> output, CancellationToken cancellationToken);
}

public sealed class ProcessRunner : IProcessRunner
{
    public async Task<ProcessResult> RunAsync(
        ProcessCommand command, Action<string> output, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!Path.IsPathFullyQualified(command.Executable))
            throw new ArgumentException("O executável precisa ter um caminho completo.");
        var info = new ProcessStartInfo(command.Executable)
        {
            UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = command.WorkingDirectory,
            RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
        };
        foreach (var argument in command.Arguments) info.ArgumentList.Add(argument);
        if (command.Environment != null)
            foreach (var pair in command.Environment)
            {
                if (pair.Value == null) info.Environment.Remove(pair.Key);
                else info.Environment[pair.Key] = pair.Value;
            }

        using var process = new Process { StartInfo = info };
        using var job = OperatingSystem.IsWindows() ? new WindowsProcessJob() : null;
        process.Start();
        try { if (OperatingSystem.IsWindows()) job?.Assign(process); }
        catch { TryKill(process); throw; } // Fail closed: never leave an unowned downloader running.
        using var registration = cancellationToken.Register(() =>
        {
            if (OperatingSystem.IsWindows()) job?.Terminate();
            TryKill(process);
        });
        var stdout = DrainAsync(process.StandardOutput, output);
        var stderr = DrainAsync(process.StandardError, output);
        try
        {
            await process.WaitForExitAsync(CancellationToken.None).ConfigureAwait(false);
            // Descendants that outlive the CLI must not retain our pipes or keep downloading.
            if (OperatingSystem.IsWindows()) job?.Dispose();
            await Task.WhenAll(stdout, stderr).WaitAsync(TimeSpan.FromSeconds(10)).ConfigureAwait(false);
        }
        catch
        {
            if (OperatingSystem.IsWindows()) job?.Terminate();
            TryKill(process);
            throw;
        }
        return new(process.ExitCode, cancellationToken.IsCancellationRequested);
    }

    private static void TryKill(Process process)
    {
        try { if (!process.HasExited) process.Kill(entireProcessTree: true); }
        catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception)
        { /* The process may have exited between the check and the kill. */ }
    }

    private static async Task DrainAsync(StreamReader reader, Action<string> output)
    {
        var buffer = new char[4096];
        var line = new StringBuilder();
        var truncated = false;
        int count;
        while ((count = await reader.ReadAsync(buffer.AsMemory()).ConfigureAwait(false)) > 0)
            for (var i = 0; i < count; i++)
            {
                var c = buffer[i];
                if (c is '\r' or '\n')
                {
                    if (line.Length > 0)
                    {
                        output(line + (truncated ? " … [linha abreviada]" : ""));
                        line.Clear(); truncated = false;
                    }
                }
                else if (line.Length < 16_384) line.Append(c);
                else truncated = true;
            }
        if (line.Length > 0) output(line + (truncated ? " … [linha abreviada]" : ""));
    }
}
