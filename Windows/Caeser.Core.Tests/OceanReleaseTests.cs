using System.Xml.Linq;
using Xunit;

namespace Caeser.Core.Tests;

public class OceanReleaseTests
{
    [Fact]
    public void NotesAppearOnlyOncePerVersionAndDowngradeDoesNotResetSeenVersion()
    {
        using var folder = new TemporaryDirectory();
        var first = new WhatsNewStore(folder.Path, "2.3.0");
        Assert.True(first.RequestAutomaticPresentation());
        Assert.False(first.RequestAutomaticPresentation());
        // A request alone is not proof that the window was displayed.
        Assert.True(new WhatsNewStore(folder.Path).RequestAutomaticPresentation());
        first.MarkPresented();
        Assert.False(new WhatsNewStore(folder.Path).RequestAutomaticPresentation());
        var older = new WhatsNewStore(folder.Path, "2.2.1");
        Assert.False(older.RequestAutomaticPresentation());
        older.MarkPresented();
        Assert.False(new WhatsNewStore(folder.Path).RequestAutomaticPresentation());
        Assert.True(new WhatsNewStore(folder.Path, "2.4.0").RequestAutomaticPresentation());
    }
    [Fact]
    public void NotesRecoverFromBadPreferencesWithoutChangingTheDownloadLibrary()
    {
        using var folder = new TemporaryDirectory();
        var library = Path.Combine(folder.Path, "library.json");
        File.WriteAllText(library, "existing history and preferences");
        File.WriteAllText(Path.Combine(folder.Path, "whats-new.json"), "{broken");
        var notes = new WhatsNewStore(folder.Path);
        Assert.True(notes.RequestAutomaticPresentation());
        notes.MarkPresented();
        Assert.Equal("existing history and preferences", File.ReadAllText(library));
        Assert.False(new WhatsNewStore(folder.Path).RequestAutomaticPresentation());
        Assert.Equal(3, notes.Highlights.Count);
        Assert.Equal("https://github.com/cnolli-fl/Caeser/releases/tag/windows-v2.3.0", notes.NotesUrl.AbsoluteUri);
        Assert.Single(new WhatsNewStore(folder.Path, "2.4.0").Highlights);
        Assert.Throws<ArgumentException>(() => new WhatsNewStore(folder.Path, "invalid"));
    }
    [Fact]
    public void ValidNewInputResumesTheQueueButDuplicatesAndInvalidInputDoNot()
    {
        using var folder = new TemporaryDirectory();
        var request = new DownloadRequest(new("https://example.com/first"), folder.Path, DownloadSource.Video);
        var library = new DesktopLibrary { Paused = true };
        Assert.Equal(1, library.AddToQueue([request]));
        Assert.False(library.Paused);
        library.Paused = true;
        Assert.Equal(0, library.AddToQueue([request]));
        Assert.True(library.Paused);
        Assert.Throws<ArgumentException>(() => DesktopLibrary.Batch("not-a-link", DownloadSource.Video, folder.Path, VideoQuality.Best, VideoFormat.Mp4, null));
        Assert.True(library.Paused);
        Assert.Equal(1, library.AddToQueue([request with { Url = new Uri("https://example.com/second") }]));
        Assert.False(library.Paused);
        Assert.Equal(2, library.Items.Count);
    }
    [Fact]
    public void QueueLimitFailureDoesNotChangePauseOrExistingItems()
    {
        using var folder = new TemporaryDirectory();
        var library = new DesktopLibrary();
        library.AddToQueue(Enumerable.Range(0, 100).Select(i => new DownloadRequest(new($"https://example.com/{i}"), folder.Path, DownloadSource.Video)).ToArray());
        library.Paused = true;
        Assert.Throws<ArgumentException>(() => library.AddToQueue([new(new("https://example.com/another"), folder.Path, DownloadSource.Video)]));
        Assert.True(library.Paused);
        Assert.Equal(100, library.Items.Count);
    }
    [Fact]
    public void OceanPalettePreservesReadableTextAndSystemHighContrastForEveryBrush()
    {
        XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";
        var xml = XDocument.Load(Path.Combine(DownloadTests.RepositoryRoot(), "Windows/Caeser.App/Themes/Ocean.xaml"));
        var dictionaries = xml.Descendants().Where(e => e.Name.LocalName == "ResourceDictionary" && e.Attribute(x + "Key") != null)
            .ToDictionary(e => e.Attribute(x + "Key")!.Value, e => e.Elements().ToDictionary(b => b.Attribute(x + "Key")!.Value, b => b.Attribute("Color")!.Value));
        foreach (var theme in new[] { "Default", "Light" })
        {
            var colors = dictionaries[theme];
            Assert.Equal("#0D2666", colors["CaeserBackground"]);
            Assert.Equal("#15FFFFFF", colors["SubtleFillColorSecondaryBrush"]);
            Assert.Equal("{ThemeResource SystemColorWindowTextColor}", dictionaries["HighContrast"]["ControlStrokeColorDefaultBrush"]);
            Assert.True(Contrast(colors["CaeserForeground"], colors["CaeserBackground"]) >= 7);
            Assert.True(Contrast(colors["CaeserSecondary"], colors["CaeserSelector"]) >= 4.5);
            foreach (var suffix in new[] { "", "PointerOver", "Pressed" })
                Assert.True(Contrast(colors["AccentButtonForeground" + suffix], colors["AccentButtonBackground" + suffix]) >= 4.5);
            foreach (var key in colors.Keys)
                Assert.StartsWith("{ThemeResource SystemColor", dictionaries["HighContrast"][key]);
        }
    }
    private static double Contrast(string a, string b)
    {
        static double L(string hex)
        {
            var values = new[] { 1, 3, 5 }.Select(i => Convert.ToInt32(hex.Substring(i, 2), 16) / 255.0)
                .Select(v => v <= .04045 ? v / 12.92 : Math.Pow((v + .055) / 1.055, 2.4)).ToArray();
            return values[0] * .2126 + values[1] * .7152 + values[2] * .0722;
        }
        return (Math.Max(L(a), L(b)) + .05) / (Math.Min(L(a), L(b)) + .05);
    }
}
