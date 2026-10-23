using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using Caeser.Core;
using Xunit;

namespace Caeser.Core.Tests;
public sealed class UpdateInstallerTests
{
    private static readonly byte[] installer = [(byte)'M', (byte)'Z', .. new byte[500]];
    private static ReleaseUpdate Update(byte[]? bytes = null) => new("2.1.1",
        new("https://github.com/cnolli-fl/Caeser/releases/tag/windows-v2.1.1"),
        new("https://github.com/cnolli-fl/Caeser/releases/download/windows-v2.1.1/Caeser-2.1.1-Windows-x64-Setup.exe"),
        Convert.ToHexString(SHA256.HashData(bytes ?? installer)), (bytes ?? installer).Length);
    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        { cancellationToken.ThrowIfCancellationRequested(); return Task.FromResult(response(request)); }
    }
    private static HttpClient Client(byte[] bytes) => new(new Handler(_ => new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) }));
    [Fact] public async Task DownloadsAndRevalidatesWithoutExecuting()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        try
        {
            using var client = Client(installer);
            var path = await new UpdateInstaller(client).DownloadAsync(Update(), root, null, CancellationToken.None);
            await UpdateInstaller.VerifyAsync(path, Update());
            Assert.Equal(installer, await File.ReadAllBytesAsync(path));
            if (OperatingSystem.IsWindows()) Assert.Contains("ZoneId=3", await File.ReadAllTextAsync(path + ":Zone.Identifier"));
            UpdateInstaller.DeleteDownload(path); Assert.False(File.Exists(path));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Theory] [InlineData(true)] [InlineData(false)]
    public async Task RejectsCorruptOrNonExecutableFilesAndCleansUp(bool corrupt)
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        var bytes = (byte[])installer.Clone(); bytes[0] = 0;
        try
        {
            using var client = Client(bytes);
            await Assert.ThrowsAsync<InvalidDataException>(() => new UpdateInstaller(client).DownloadAsync(corrupt ? Update() : Update(bytes), root, null, CancellationToken.None));
            Assert.Empty(Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Fact] public async Task RejectsTamperingAfterDownload()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        try
        {
            using var client = Client(installer);
            var path = await new UpdateInstaller(client).DownloadAsync(Update(), root, null, CancellationToken.None);
            var changed = (byte[])installer.Clone(); changed[10] = 1;
            await File.WriteAllBytesAsync(path, changed);
            await Assert.ThrowsAsync<InvalidDataException>(() => UpdateInstaller.VerifyAsync(path, Update()));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Fact] public async Task RejectsUntrustedRedirect()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        try
        {
            using var client = new HttpClient(new Handler(_ => { var response = new HttpResponseMessage(HttpStatusCode.Found); response.Headers.Location = new("https://evil.example/setup.exe"); return response; }));
            await Assert.ThrowsAsync<InvalidDataException>(() => new UpdateInstaller(client).DownloadAsync(Update(), root, null, CancellationToken.None));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Fact] public void RequiresOfficialWindowsUrlSizeHashAndNewInstallerContract()
    {
        Assert.True(Update().CanInstall);
        Assert.False((Update() with { Sha256 = null }).CanInstall);
        Assert.False((Update() with { Sha256 = new string('z', 64) }).CanInstall);
        Assert.False((Update() with { Size = UpdateInstaller.MaximumBytes + 1 }).CanInstall);
        Assert.False((Update() with { Version = "2.0.1" }).CanInstall);
        Assert.Throws<InvalidDataException>(() => UpdateInstaller.Validate(Update() with { Download = new("https://evil.example/setup.exe") }));
        Assert.False(UpdateInstaller.TrustedDownload(new("http://github.com/a")));
        Assert.False(UpdateInstaller.TrustedDownload(new("https://github.com.evil.example/a")));
        Assert.False(UpdateInstaller.TrustedDownload(new("https://user@github.com/a")));
        Assert.True(UpdateInstaller.TrustedDownload(new("https://release-assets.githubusercontent.com/a")));
    }
    [Fact] public void InstallerUsesWindowsSecurityChecksAndNeverForceClosesOrReboots()
    {
        var info = UpdateInstaller.StartInfo(Path.Combine(Path.GetTempPath(), "instalador com espaço.exe"), Path.Combine(Path.GetTempPath(), "Caeser ação"));
        Assert.True(info.UseShellExecute);
        Assert.EndsWith("instalador com espaço.exe", info.FileName);
        Assert.Contains("/CAESERUPDATE=1", info.ArgumentList); Assert.Contains("/NORESTART", info.ArgumentList);
        Assert.Contains("/NOFORCECLOSEAPPLICATIONS", info.ArgumentList); Assert.DoesNotContain("/SUPPRESSMSGBOXES", info.ArgumentList);
        Assert.Single(info.ArgumentList.Where(a => a.StartsWith("/DIR=")));
    }
    [Fact] public async Task CancellationLeavesNoInstaller()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        try
        {
            using var client = Client(installer); using var cancellation = new CancellationTokenSource(); cancellation.Cancel();
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => new UpdateInstaller(client).DownloadAsync(Update(), root, null, cancellation.Token));
            Assert.Empty(Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Fact] public void ReleaseMetadataIncludesDigestForInAppDownload()
    {
        var update = Update();
        var json = JsonSerializer.Serialize(new[] { new { tag_name = "windows-v2.1.1", draft = false, prerelease = false,
            html_url = update.Page.AbsoluteUri, assets = new[] { new { name = "Caeser-2.1.1-Windows-x64-Setup.exe", size = update.Size,
            state = "uploaded", browser_download_url = update.Download.AbsoluteUri, digest = "sha256:" + update.Sha256 } } } });
        Assert.True(ReleaseUpdates.Parse(json, new Version(2, 1, 0))?.CanInstall);
    }
    [Fact] public async Task RejectsWrongLengthBeforeRetainingInstaller()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        try
        {
            using var client = Client(installer);
            await Assert.ThrowsAsync<InvalidDataException>(() => new UpdateInstaller(client).DownloadAsync(Update() with { Size = 999 }, root, null, CancellationToken.None));
            Assert.Empty(Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
    [Fact] public void CleanupOnlyRemovesOldKnownInstallerFiles()
    {
        var root = Path.Combine(Path.GetTempPath(), "Caeser-update-test-" + Guid.NewGuid());
        var directory = Path.Combine(root, Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(directory);
            var old = Path.Combine(directory, "Caeser-2.1.1-Setup.exe"); File.WriteAllBytes(old, installer); File.SetLastWriteTimeUtc(old, DateTime.UtcNow.AddDays(-2));
            var sentinel = Path.Combine(directory, "arquivo-do-usuario.txt"); File.WriteAllText(sentinel, "Preservar");
            UpdateInstaller.CleanupOldDownloads(root);
            Assert.False(File.Exists(old)); Assert.True(File.Exists(sentinel));
        }
        finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
    }
}
