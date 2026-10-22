using System.Globalization;
using System.Text.RegularExpressions;

namespace Caeser.Core;

public sealed partial class DownloadProgress
{
    public double? Fraction { get; private set; }
    public string Status { get; private set; } = "Preparando download…";
    public string Speed { get; private set; } = "";
    public string Eta { get; private set; } = "";
    public string? SpotifyError { get; private set; }
    public int SpotifyProcessed { get; private set; }

    public string Receive(string line, DownloadSource source)
    {
        var clean = Ansi().Replace(line, "").Trim();
        if (clean.Length == 0) return clean;
        if (source == DownloadSource.Spotify)
        {
            var parts = clean.Split('|', 3);
            var tagged = parts.Length == 3 && parts[0] == "SPOTDL";
            var message = tagged ? parts[2] : clean;
            if (tagged && parts[1] is "ERROR" or "CRITICAL") SpotifyError = message;
            var complete = Complete().Match(message);
            if (complete.Success &&
                int.TryParse(complete.Groups[1].Value, out var count) &&
                int.TryParse(complete.Groups[2].Value, out var total) && total > 0)
            {
                SpotifyProcessed = count;
                Fraction = Math.Clamp((double)count / total, 0, 0.99);
                Speed = $"{count} de {total} músicas processadas";
            }
            if (message.Contains("Searching for song", StringComparison.OrdinalIgnoreCase))
                Status = "Buscando a versão correspondente no YouTube…";
            else if (message.Contains("Downloading", StringComparison.OrdinalIgnoreCase))
                Status = "Baixando áudio do YouTube…";
            else if (message.Contains("Converting", StringComparison.OrdinalIgnoreCase))
                Status = "Convertendo para MP3…";
            else if (message.Contains("Embedding metadata", StringComparison.OrdinalIgnoreCase))
                Status = "Adicionando capa e informações…";
            else if (message.StartsWith("Downloaded", StringComparison.OrdinalIgnoreCase))
                Status = "Música salva. Preparando a próxima…";
            return clean;
        }
        if (clean.StartsWith("download:", StringComparison.Ordinal))
        {
            var values = clean["download:".Length..].Split('|');
            var percent = values[0].Replace("%", "").Trim().Replace(',', '.');
            if (double.TryParse(percent, NumberStyles.Float, CultureInfo.InvariantCulture, out var number) &&
                double.IsFinite(number))
            {
                Fraction = Math.Clamp(number / 100, 0, 1);
                Status = $"Baixando… {values[0].Trim()}";
            }
            if (values.Length > 3 && Useful(values[3])) Speed = values[3].Trim();
            if (values.Length > 4 && Useful(values[4])) Eta = $"Tempo restante: {values[4].Trim()} s";
        }
        else if (clean.Contains("[Merger]", StringComparison.Ordinal))
        { Fraction = null; Status = "Unindo vídeo e áudio…"; }
        else if (clean.Contains("[ExtractAudio]", StringComparison.Ordinal))
        { Fraction = null; Status = "Convertendo para MP3…"; }
        return clean;
    }

    public string? CompletionError(int exitCode, DownloadSource source, string? report)
    {
        if (source == DownloadSource.Spotify)
        {
            if (!string.IsNullOrWhiteSpace(report)) return report.Trim();
            // Some spotDL errors are logged even though its exit code is zero.
            if (SpotifyError != null) return SpotifyError;
            if (SpotifyProcessed == 0)
                return "Nenhuma música foi processada. Confira se o link aponta para uma música ou coleção pública disponível.";
        }
        return exitCode == 0 ? null :
            $"A ferramenta encerrou com código {exitCode}. Confira o link, a conexão e os detalhes do registro.";
    }

    private static bool Useful(string value) =>
        !string.IsNullOrWhiteSpace(value) && !value.Contains("N/A") && !value.Contains("Unknown");
    [GeneratedRegex(@"\x1B\[[0-?]*[ -/]*[@-~]")]
    private static partial Regex Ansi();
    [GeneratedRegex(@"^(\d+)/(\d+) complete$", RegexOptions.CultureInvariant)]
    private static partial Regex Complete();
}
