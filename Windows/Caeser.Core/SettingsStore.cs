using System.Text.Json;

namespace Caeser.Core;

public sealed record UserSettings(string Destination);

public sealed class SettingsStore
{
    private readonly string file;
    public SettingsStore(string? directory = null) =>
        file = Path.Combine(directory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Caeser"), "settings.json");

    public string? LoadDestination()
    {
        try
        {
            var value = JsonSerializer.Deserialize<UserSettings>(File.ReadAllText(file))?.Destination;
            return value != null && Path.IsPathFullyQualified(value) ? value : null;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException)
        { return null; }
    }

    public void SaveDestination(string destination)
    {
        if (!Path.IsPathFullyQualified(destination))
            throw new ArgumentException("Escolha uma pasta com um caminho completo.");
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temporary = file + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(new UserSettings(destination)));
            File.Move(temporary, file, overwrite: true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
