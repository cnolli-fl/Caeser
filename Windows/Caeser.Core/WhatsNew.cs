using System.Text.Json;

namespace Caeser.Core;

public sealed record ReleaseHighlight(string Glyph, string Title, string Detail);

public sealed class WhatsNewStore
{
    private readonly string file;
    private bool requested;
    public static string CurrentVersion => typeof(WhatsNewStore).Assembly.GetName().Version?.ToString(3) ?? "2.3.0";
    public string VersionText { get; }
    public Uri NotesUrl => new($"https://github.com/cnolli-fl/Caeser/releases/tag/windows-v{VersionText}");
    public WhatsNewStore(string? directory = null, string? version = null)
    {
        version ??= CurrentVersion;
        if (!Version.TryParse(version, out var parsed) || parsed.Build < 0 || parsed.Revision > 0)
            throw new ArgumentException("Versão de release inválida.", nameof(version));
        VersionText = parsed.ToString(3);
        file = Path.Combine(directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Caeser"), "whats-new.json");
    }
    public IReadOnlyList<ReleaseHighlight> Highlights => VersionText == "2.3.0" ? [
        new("\uE790", "O mesmo azul do Mac", "Fundo azul, texto claro e nota musical branca, com controles nativos do Windows."),
        new("\uE8A5", "As novidades, aqui no app", "Esta janela aparece uma vez por versão, mesmo sem internet. Consulte novamente no botão Novidades da barra superior."),
        new("\uE896", "Adicionar e já baixar", "Um link válido inicia ou retoma a fila em uma ação. Sua fila, histórico e preferências são mantidos.")
    ] : [new("\uE8A5", "Uma nova versão do Caeser", "Consulte as notas completas desta versão para conhecer as mudanças.")];

    private Version? ReadSeen()
    {
        try
        {
            if (!File.Exists(file) || new FileInfo(file).Length > 1024) return null;
            var value = JsonSerializer.Deserialize<string>(File.ReadAllText(file));
            return Version.TryParse(value, out var version) ? version : null;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return null; }
    }
    public bool RequestAutomaticPresentation()
    {
        if (requested) return false;
        requested = true;
        return ReadSeen() is not { } seen || seen < Version.Parse(VersionText);
    }
    public void MarkPresented()
    {
        if (ReadSeen() is { } seen && seen >= Version.Parse(VersionText)) return;
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temporary = file + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllText(temporary, JsonSerializer.Serialize(VersionText)); File.Move(temporary, file, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
