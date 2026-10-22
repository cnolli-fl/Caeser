using System.Net.Http;
using System.Text.Json;

namespace Caeser.Core;
public sealed record ReleaseUpdate(string Version, Uri Page, Uri Download);
public static class ReleaseUpdates
{
    private static readonly HttpClient client = new() { Timeout = TimeSpan.FromSeconds(20) };
    public static ReleaseUpdate? Parse(string json, Version current)
    {
        using var document = JsonDocument.Parse(json);
        var matches = new List<(Version Version, ReleaseUpdate Update)>();
        foreach (var release in document.RootElement.EnumerateArray())
        {
            var tag = release.GetProperty("tag_name").GetString() ?? "";
            if (!tag.StartsWith("windows-v", StringComparison.Ordinal) || release.GetProperty("draft").GetBoolean() || release.GetProperty("prerelease").GetBoolean()) continue;
            var text = tag[9..];
            if (text.Split('.').Length != 3 || !Version.TryParse(text, out var version) || version <= current) continue;
            var name = $"Caeser-{text}-Windows-x64-Setup.exe";
            var page = $"https://github.com/cnolli-fl/Caeser/releases/tag/{tag}";
            var download = $"https://github.com/cnolli-fl/Caeser/releases/download/{tag}/{name}";
            if (release.GetProperty("html_url").GetString() != page) continue;
            if (release.GetProperty("assets").EnumerateArray().Any(a => a.GetProperty("name").GetString() == name &&
                a.GetProperty("size").GetInt64() > 0 && a.GetProperty("state").GetString() == "uploaded" && a.GetProperty("browser_download_url").GetString() == download))
                matches.Add((version, new(text, new(page), new(download))));
        }
        return matches.OrderByDescending(x => x.Version).FirstOrDefault().Update;
    }
    public static async Task<ReleaseUpdate?> CheckAsync(Version current, CancellationToken token = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://api.github.com/repos/cnolli-fl/Caeser/releases?per_page=100");
        request.Headers.UserAgent.ParseAdd("Caeser-Windows/2.0.0");
        using var response = await client.SendAsync(request, token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync(token).ConfigureAwait(false);
        if (json.Length > 4_000_000) throw new IOException("Resposta muito grande.");
        return Parse(json, current);
    }
}
