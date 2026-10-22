using System.Runtime.InteropServices.WindowsRuntime;
using System.Text.Json;
using Caeser.App.Controls;
using Caeser.App.ViewModels;
using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
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
        foreach (var theme in new[] { ElementTheme.Dark, ElementTheme.Light })
        {
            root.RequestedTheme = theme;
            selector.SelectedSource = DownloadSource.Video;
            await Task.Delay(400);
            await CaptureAsync(root, directory, $"youtube-{theme.ToString().ToLowerInvariant()}.png");
            selector.SelectedSource = DownloadSource.Spotify;
            await Task.Delay(400);
            if (model.Source != DownloadSource.Spotify || model.SpotifyVisibility != Visibility.Visible)
                throw new InvalidOperationException("A seleção Spotify não atualizou o formulário.");
            await CaptureAsync(root, directory, $"spotify-{theme.ToString().ToLowerInvariant()}.png");
        }
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
            urlValidation = true, sourceSwitch = true, keyboardFocus = focusWorks,
            note = "Capturas reais do XAML no runner. Não substitui teste manual no Windows 10/11."
        }, new JsonSerializerOptions { WriteIndented = true }));
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
