namespace Caeser.Core;

public sealed record DownloadResult(bool Succeeded, bool Cancelled, string? Error);

public sealed class DownloadSession(ToolLocator tools, IProcessRunner runner)
{
    public async Task<DownloadResult> RunAsync(
        DownloadRequest request, Action<string> output, CancellationToken cancellationToken)
    {
        var missing = tools.Missing(request.Source);
        if (missing.Count > 0)
            return new(false, false,
                $"Pacote incompleto: {string.Join(", ", missing)}. Extraia o pacote inteiro ou reinstale o Caeser.");
        string? temporary = null;
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            Directory.CreateDirectory(request.Destination);
            // Probe only a uniquely named file owned by this run; never overwrite a user's file.
            var probe = Path.Combine(request.Destination, $".caeser-write-{Guid.NewGuid():N}");
            using (new FileStream(probe, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1, FileOptions.DeleteOnClose)) { }
            var progress = new DownloadProgress();
            ProcessCommand command;
            string? report = null;
            if (request.Source == DownloadSource.Spotify)
            {
                temporary = Path.Combine(Path.GetTempPath(), $"Caeser-{Guid.NewGuid():N}");
                Directory.CreateDirectory(temporary);
                report = Path.Combine(temporary, "errors.txt");
                command = new(tools.Tool("spotdl.exe"),
                    request.SpotifyArguments(tools.Tool("ffmpeg.exe"), report),
                    request.Destination, tools.EnvironmentVariables());
            }
            else
                command = new(tools.Tool("yt-dlp.exe"), request.VideoArguments(tools.ToolsDirectory),
                    request.Destination, tools.EnvironmentVariables());
            var gate = new object();
            var result = await runner.RunAsync(command, line =>
            {
                // stdout/stderr are drained concurrently. Keep completion state coherent.
                lock (gate)
                {
                    var clean = progress.Receive(line, request.Source);
                    if (clean.Length > 0) output(clean);
                }
            }, cancellationToken).ConfigureAwait(false);
            if (result.Cancelled || cancellationToken.IsCancellationRequested) return new(false, true, null);
            string? errors = null;
            if (report != null && File.Exists(report))
            {
                using var reader = new StreamReader(report);
                var text = new char[4096];
                var length = await reader.ReadBlockAsync(text).ConfigureAwait(false);
                errors = new string(text, 0, length);
            }
            var error = progress.CompletionError(result.ExitCode, request.Source, errors);
            return new(error == null, false, error);
        }
        catch (OperationCanceledException) { return new(false, true, null); }
        catch (UnauthorizedAccessException)
        { return new(false, false, "Esta pasta não permite salvar arquivos. Escolha outra pasta de destino."); }
        catch (Exception e) when (e is IOException or System.ComponentModel.Win32Exception or TimeoutException)
        { return new(false, false, $"Não consegui concluir o download: {e.Message}"); }
        finally
        {
            // This exact temporary directory was created above; downloaded media is never removed.
            if (temporary != null)
                try { Directory.Delete(temporary, recursive: true); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        }
    }
}
