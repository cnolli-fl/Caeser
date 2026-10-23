using System.Diagnostics;
using System.Net;
using System.Security.Cryptography;

namespace Caeser.Core;

public sealed class UpdateInstaller
{
    public const long MaximumBytes = 512L * 1024 * 1024;
    private static readonly HttpClient client = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = Timeout.InfiniteTimeSpan };
    private readonly HttpClient transport;
    public UpdateInstaller(HttpClient? transport = null) => this.transport = transport ?? client;
    public static void Validate(ReleaseUpdate update)
    {
        if (!update.CanInstall || update.Page.AbsoluteUri != $"https://github.com/cnolli-fl/Caeser/releases/tag/windows-v{update.Version}" ||
            update.Download.AbsoluteUri != $"https://github.com/cnolli-fl/Caeser/releases/download/windows-v{update.Version}/Caeser-{update.Version}-Windows-x64-Setup.exe")
            throw new InvalidDataException("Esta versão não possui um instalador verificável. Use a página oficial da release.");
    }
    public static bool TrustedDownload(Uri uri) => uri.Scheme == "https" && uri.Port == 443 && string.IsNullOrEmpty(uri.UserInfo) &&
        uri.Host is "github.com" or "release-assets.githubusercontent.com" or "objects.githubusercontent.com";

    public async Task<string> DownloadAsync(ReleaseUpdate update, string root, IProgress<double>? progress, CancellationToken token)
    {
        Validate(update);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
        timeout.CancelAfter(TimeSpan.FromMinutes(15)); token = timeout.Token;
        var directory = Path.Combine(root, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, $"Caeser-{update.Version}-Setup.exe");
        try
        {
            var uri = update.Download;
            for (var redirects = 0; redirects <= 5; redirects++)
            {
                if (!TrustedDownload(uri)) throw new InvalidDataException("O download saiu dos servidores oficiais do GitHub.");
                using var request = new HttpRequestMessage(HttpMethod.Get, uri);
                request.Headers.UserAgent.ParseAdd("Caeser-Windows-Updater/1.0");
                using var response = await transport.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token).ConfigureAwait(false);
                if (response.StatusCode is HttpStatusCode.MovedPermanently or HttpStatusCode.Found or HttpStatusCode.SeeOther or HttpStatusCode.TemporaryRedirect or HttpStatusCode.PermanentRedirect)
                {
                    uri = response.Headers.Location is { } location ? new Uri(uri, location) : throw new InvalidDataException("Redirecionamento inválido.");
                    continue;
                }
                response.EnsureSuccessStatusCode();
                if (response.StatusCode != HttpStatusCode.OK || response.Content.Headers.ContentLength is { } size && size != update.Size)
                    throw new InvalidDataException("O tamanho do instalador não corresponde à release.");
                await using (var input = await response.Content.ReadAsStreamAsync(token).ConfigureAwait(false))
                await using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
                using (var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
                {
                    byte[] buffer = new byte[81920]; long received = 0;
                    int count;
                    while ((count = await input.ReadAsync(buffer, token).ConfigureAwait(false)) > 0)
                    {
                        received += count;
                        if (received > update.Size) throw new InvalidDataException("O instalador é maior que o esperado.");
                        hash.AppendData(buffer, 0, count);
                        await output.WriteAsync(buffer.AsMemory(0, count), token).ConfigureAwait(false);
                        progress?.Report(100d * received / update.Size);
                    }
                    if (received != update.Size || !Convert.ToHexString(hash.GetHashAndReset()).Equals(update.Sha256, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("A conferência de integridade falhou. Nada foi instalado.");
                }
                await VerifyAsync(path, update, token).ConfigureAwait(false);
                if (OperatingSystem.IsWindows())
                {
                    // Preserve Windows' Internet-origin checks for unsigned installers.
                    // Never use Unblock-File or suppress SmartScreen/UAC.
                    await File.WriteAllTextAsync(path + ":Zone.Identifier", "[ZoneTransfer]\r\nZoneId=3\r\nHostUrl=" + update.Download.AbsoluteUri + "\r\n", token).ConfigureAwait(false);
                }
                return path;
            }
            throw new InvalidDataException("Muitos redirecionamentos ao baixar a atualização.");
        }
        catch { DeleteDownload(path); throw; }
    }
    public static async Task VerifyAsync(string path, ReleaseUpdate update, CancellationToken token = default)
    {
        Validate(update);
        await using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
        await VerifyStreamAsync(file, update, token).ConfigureAwait(false);
    }
    private static async Task VerifyStreamAsync(FileStream file, ReleaseUpdate update, CancellationToken token)
    {
        if (file.Length != update.Size || file.ReadByte() != 'M' || file.ReadByte() != 'Z') throw new InvalidDataException("Instalador inválido.");
        file.Position = 0;
        var digest = await SHA256.HashDataAsync(file, token).ConfigureAwait(false);
        if (!Convert.ToHexString(digest).Equals(update.Sha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("O instalador foi alterado. Baixe a atualização novamente.");
    }
    public static ProcessStartInfo StartInfo(string path, string installation)
    {
        var result = new ProcessStartInfo(Path.GetFullPath(path)) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(Path.GetFullPath(path))! };
        foreach (var argument in new[] { "/SILENT", "/SP-", "/NORESTART", "/CLOSEAPPLICATIONS", "/NOFORCECLOSEAPPLICATIONS", "/NORESTARTAPPLICATIONS", "/CAESERUPDATE=1", "/DIR=" + Path.GetFullPath(installation) }) result.ArgumentList.Add(argument);
        return result;
    }
    public static async Task LaunchAsync(string path, string installation, ReleaseUpdate update)
    {
        Validate(update);
        // Keep the executable read-locked between revalidation and CreateProcess.
        await using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
        await VerifyStreamAsync(file, update, CancellationToken.None);
        using var process = Process.Start(StartInfo(path, installation)) ?? throw new IOException("Não consegui abrir o instalador.");
    }
    public static void DeleteDownload(string path)
    {
        try { File.Delete(path); Directory.Delete(Path.GetDirectoryName(path)!); }
        catch (IOException) { } catch (UnauthorizedAccessException) { }
    }
    public static void CleanupOldDownloads(string root)
    {
        if (!Directory.Exists(root) || File.GetAttributes(root).HasFlag(FileAttributes.ReparsePoint)) return;
        try
        {
            foreach (var directory in Directory.EnumerateDirectories(root).Take(100))
            {
                if (!Guid.TryParseExact(Path.GetFileName(directory), "N", out _) || File.GetAttributes(directory).HasFlag(FileAttributes.ReparsePoint)) continue;
                foreach (var file in Directory.EnumerateFiles(directory))
                {
                    if (!File.GetAttributes(file).HasFlag(FileAttributes.ReparsePoint) && System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(file), @"^Caeser-\d+\.\d+\.\d+-Setup\.exe$") &&
                        File.GetLastWriteTimeUtc(file) < DateTime.UtcNow.AddDays(-1)) File.Delete(file);
                }
                if (!Directory.EnumerateFileSystemEntries(directory).Any()) Directory.Delete(directory);
            }
        }
        catch (IOException) { } catch (UnauthorizedAccessException) { }
    }
}
