using System.Runtime.InteropServices.WindowsRuntime;
using System.Text.Json;
using Caeser.App.Controls;
using Caeser.App.ViewModels;
using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Automation.Provider;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Foundation;
using Windows.Graphics.Imaging;
using Windows.Storage;

namespace Caeser.App;

/// <summary>Opt-in UI smoke test used by CI; normal launches never execute this path.</summary>
internal static class UiSmokeTest
{
    public static async Task RunAsync(Window window, FrameworkElement root, SourceSelector selector,
        TextBox url, DownloadViewModel model, string outputDirectory)
    {
        var directory = Path.GetFullPath(outputDirectory);
        Directory.CreateDirectory(directory);
        // CI desktops often disable animation. Exercise the same animated path
        // as a normal Windows desktop instead of silently skipping it.
        selector.MotionEnabledOverride = true;
        foreach (var theme in new[] { ElementTheme.Dark, ElementTheme.Light })
        {
            root.RequestedTheme = theme;
            selector.SelectedSource = DownloadSource.Video;
            await Task.Delay(400);
            await CheckLayoutAsync(root, directory);
            await CaptureAsync(root, directory, $"youtube-{theme.ToString().ToLowerInvariant()}.png");
            selector.SelectedSource = DownloadSource.Spotify;
            await Task.Delay(400);
            await CheckLayoutAsync(root, directory);
            if (model.Source != DownloadSource.Spotify || model.SpotifyVisibility != Visibility.Visible)
                throw new InvalidOperationException("A seleção Spotify não atualizou o formulário.");
            await CaptureAsync(root, directory, $"spotify-{theme.ToString().ToLowerInvariant()}.png");
        }
        ToggleThroughAutomation(selector, "YouTubeButton");
        if (model.Source != DownloadSource.Video)
            throw new InvalidOperationException("A automação de acessibilidade não selecionou YouTube.");
        ToggleThroughAutomation(selector, "YouTubeButton");
        if (model.Source != DownloadSource.Video)
            throw new InvalidOperationException("A origem selecionada não pode ficar vazia.");
        ToggleThroughAutomation(selector, "SpotifyButton");
        if (model.Source != DownloadSource.Spotify)
            throw new InvalidOperationException("A automação de acessibilidade não selecionou Spotify.");
        model.UrlText = "isso não é um link";
        await model.StartAsync();
        if (model.Error == null || model.IsBusy)
            throw new InvalidOperationException("Um link inválido não foi tratado antes de iniciar o processo.");
        var focusWorks = url.Focus(FocusState.Keyboard);
        if (!focusWorks) throw new InvalidOperationException("O campo de URL não recebeu foco.");
        model.UrlText = "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT";
        if (model.Source != DownloadSource.Spotify)
            throw new InvalidOperationException("O reconhecimento automático de Spotify falhou.");
        var files = Directory.GetFiles(directory, "*.png");
        if (files.Length != 4 || files.Any(f => new FileInfo(f).Length < 2000))
            throw new InvalidOperationException("A captura real da interface está incompleta.");
        await File.WriteAllTextAsync(Path.Combine(directory, "result.json"), JsonSerializer.Serialize(new
        {
            succeeded = true, title = window.Title, screenshots = files.Select(Path.GetFileName),
            urlValidation = true, sourceSwitch = true, accessibleSourceSwitch = true, keyboardFocus = focusWorks,
            note = "Capturas reais do XAML no runner. Não substitui teste manual no Windows 10/11."
        }, new JsonSerializerOptions { WriteIndented = true }));
    }
    private static void ToggleThroughAutomation(SourceSelector selector, string name)
    {
        var element = selector.FindName(name) as FrameworkElement ??
            throw new InvalidOperationException("O botão de origem não foi encontrado.");
        var peer = FrameworkElementAutomationPeer.CreatePeerForElement(element);
        if (peer.GetPattern(PatternInterface.Toggle) is not IToggleProvider toggle)
            throw new InvalidOperationException("O seletor não expõe seu estado à automação de acessibilidade.");
        toggle.Toggle();
    }
    private static async Task CheckLayoutAsync(FrameworkElement root, string directory)
    {
        var bounds = new Dictionary<string, Rect>();
        foreach (var name in new[] { "ContentFrame", "SourceBar", "UrlBox", "PasteButton", "FolderButton" })
        {
            var element = root.FindName(name) as FrameworkElement ??
                throw new InvalidOperationException($"Controle ausente: {name}");
            bounds[name] = element.TransformToVisual(root).TransformBounds(new Rect(0, 0, element.ActualWidth, element.ActualHeight));
        }
        await File.WriteAllTextAsync(Path.Combine(directory, "layout.json"), JsonSerializer.Serialize(new
        {
            viewportWidth = root.ActualWidth,
            controls = bounds.ToDictionary(p => p.Key, p => new { p.Value.X, p.Value.Y, p.Value.Width, p.Value.Height })
        }, new JsonSerializerOptions { WriteIndented = true }));
        if (bounds.Any(p => p.Value.Width < 1 || p.Value.Left < -1 || p.Value.Right > root.ActualWidth + 1))
            throw new InvalidOperationException("A interface ultrapassou a largura da janela. Consulte layout.json.");
        var selector = (SourceSelector)root.FindName("SourceBar");
        foreach (var name in new[] { "YouTubeButton", "SpotifyButton" })
        {
            var button = (ToggleButton)selector.FindName(name);
            var label = FindVisual<TextBlock>(button, "Label");
            var mark = FindVisual<BitmapIcon>(button, "Mark");
            if (label?.Foreground is not SolidColorBrush text || mark?.Foreground is not SolidColorBrush icon)
                throw new InvalidOperationException("O seletor não apresentou a marca e o texto esperados.");
            var expectedRed = button.IsChecked == true ? 255 : root.ActualTheme == ElementTheme.Light ? 28 : 242;
            if (text.Color.R != expectedRed || icon.Color.R != expectedRed)
                throw new InvalidOperationException($"Contraste incorreto em {name}: tema {root.ActualTheme}, selecionado {button.IsChecked}.");
        }
    }
    private static T? FindVisual<T>(DependencyObject parent, string name) where T : FrameworkElement
    {
        if (parent is T element && element.Name == name) return element;
        for (var i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
            if (FindVisual<T>(VisualTreeHelper.GetChild(parent, i), name) is { } found) return found;
        return null;
    }
    private static async Task CaptureAsync(FrameworkElement root, string directory, string name)
    {
        var bitmap = new RenderTargetBitmap();
        await bitmap.RenderAsync(root);
        var pixels = await bitmap.GetPixelsAsync();
        var folder = await StorageFolder.GetFolderFromPathAsync(directory);
        var file = await folder.CreateFileAsync(name, CreationCollisionOption.ReplaceExisting);
        using var stream = await file.OpenAsync(FileAccessMode.ReadWrite);
        var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, stream);
        encoder.SetPixelData(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied,
            (uint)bitmap.PixelWidth, (uint)bitmap.PixelHeight, 96, 96, pixels.ToArray());
        await encoder.FlushAsync();
    }
    public static async Task RecordFailureAsync(string directory, Exception error)
    {
        Directory.CreateDirectory(Path.GetFullPath(directory));
        await File.WriteAllTextAsync(Path.Combine(directory, "result.json"),
            JsonSerializer.Serialize(new { succeeded = false, error = error.ToString() }));
    }
}
