using System.Runtime.InteropServices.WindowsRuntime;
using System.Runtime.InteropServices;
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
        await Task.Delay(700); // Root.Loaded precedes the first activated desktop frame.
        await ClickSourceAsync(window, root, selector, model, "SpotifyButton", DownloadSource.Spotify);
        await ClickSourceAsync(window, root, selector, model, "YouTubeButton", DownloadSource.Video);
        // Interrupt an in-flight animation repeatedly, not just at rest.
        for (var i = 0; i < 8; i++)
            await ClickSourceAsync(window, root, selector, model,
                i % 2 == 0 ? "SpotifyButton" : "YouTubeButton",
                i % 2 == 0 ? DownloadSource.Spotify : DownloadSource.Video);
        await DragSourceAsync(window, root, selector, model, false);
        await DragSourceAsync(window, root, selector, model, true);
        ((RadioButton)selector.FindName("YouTubeButton")).Focus(FocusState.Keyboard);
        await Task.Delay(50);
        await PressKeyAsync(0x27); // Right arrow.
        if (model.Source != DownloadSource.Spotify) throw new InvalidOperationException($"Seta direita não selecionou Spotify. {selector.PointerDiagnostics}");
        await PressKeyAsync(0x24); // Home.
        if (model.Source != DownloadSource.Video) throw new InvalidOperationException("Home não selecionou YouTube.");
        await PressKeyAsync(0x23); // End.
        await PressKeyAsync(0x20); // Space cannot clear the selected source.
        if (model.Source != DownloadSource.Spotify) throw new InvalidOperationException("O teclado desmarcou a origem selecionada.");
        // Binding setters must ignore writing the same selected item back.
        var notifications = 0;
        System.ComponentModel.PropertyChangedEventHandler countChange = (_, _) => notifications++;
        model.PropertyChanged += countChange;
        model.Quality = model.Quality;
        model.Format = model.Format;
        model.Source = model.Source;
        model.PropertyChanged -= countChange;
        if (notifications != 0) throw new InvalidOperationException("O formulário notificou uma mudança de seleção inexistente.");
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
        selector.MotionEnabledOverride = false;
        selector.SelectedSource = DownloadSource.Video;
        selector.SelectedSource = DownloadSource.Spotify;
        if (model.Source != DownloadSource.Spotify) throw new InvalidOperationException("A seleção falhou com movimento reduzido.");
        model.UrlText = "isso não é um link";
        await model.StartAsync();
        if (model.Error == null || model.IsBusy)
            throw new InvalidOperationException("Um link inválido não foi tratado antes de iniciar o processo.");
        var focusWorks = url.Focus(FocusState.Keyboard);
        if (!focusWorks) throw new InvalidOperationException("O campo de URL não recebeu foco.");
        model.UrlText = "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT";
        if (model.Source != DownloadSource.Spotify)
            throw new InvalidOperationException("O reconhecimento automático de Spotify falhou.");
        model.UrlText = "";
        model.ConfigureFeatureSmoke();
        foreach (var theme in new[] { ElementTheme.Dark, ElementTheme.Light })
        {
            root.RequestedTheme = theme;
            await Task.Delay(300);
            await CaptureAsync(root, directory, $"features-{theme.ToString().ToLowerInvariant()}.png");
            var history = model.History.ToList();
            history[0].Title = "Um título comprido para conferir o alinhamento do histórico e das ações sem aumentar a janela";
            history.Add(new() { Request = history[0].Request, Title = "Música que não pôde ser baixada", State = QueueState.Failed,
                Detail = "Não foi possível acessar este conteúdo. Este texto longo não deve empurrar os botões para fora da janela." });
            foreach (var empty in new[] { false, true })
            {
                var dialog = ((MainWindow)window).CreateHistoryDialog(empty ? [] : history, _ => { });
                var shown = dialog.ShowAsync();
                await Task.Delay(400);
                var content = (FrameworkElement)dialog.Content;
                var subtitle = (TextBlock)((StackPanel)content).Children[0];
                var foreground = ((SolidColorBrush)subtitle.Foreground).Color;
                var brightness = foreground.R + foreground.G + foreground.B;
                if (theme == ElementTheme.Dark ? brightness < 384 : brightness > 384)
                    throw new InvalidOperationException("O texto secundário do histórico não acompanhou o tema.");
                if (content.ActualWidth > root.ActualWidth || content.ActualHeight > root.ActualHeight || content.ActualWidth < 240)
                    throw new InvalidOperationException("O histórico ultrapassou a área da janela.");
                await CaptureAsync(dialog, directory, $"history-{(empty ? "empty" : "items")}-{theme.ToString().ToLowerInvariant()}.png");
                dialog.Hide(); await shown;
            }
            var updateDialog = ((MainWindow)window).CreateUpdateDownloadDialog("2.1.1 · teste de interface", out var updateMessage, out var updateProgress);
            var updateShown = updateDialog.ShowAsync();
            updateProgress.Value = 60; updateMessage.Text = "Baixando atualização · 60%";
            await Task.Delay(300);
            if (updateDialog.IsPrimaryButtonEnabled) throw new InvalidOperationException("A instalação foi oferecida antes da verificação.");
            await CaptureAsync(updateDialog, directory, $"update-download-{theme.ToString().ToLowerInvariant()}.png");
            updateMessage.Text = MainWindow.UpdateReadyMessage; updateProgress.Value = 100;
            updateDialog.IsPrimaryButtonEnabled = true; updateDialog.CloseButtonText = "Depois";
            await Task.Delay(150);
            await CaptureAsync(updateDialog, directory, $"update-ready-{theme.ToString().ToLowerInvariant()}.png");
            await PressKeyAsync(0x1B);
            if (await updateShown != ContentDialogResult.None) throw new InvalidOperationException("Escape não cancelou a atualização.");
        }
        var files = Directory.GetFiles(directory, "*.png");
        if (files.Length != 14 || files.Any(f => new FileInfo(f).Length < 2000))
            throw new InvalidOperationException("A captura real da interface está incompleta.");
        await File.WriteAllTextAsync(Path.Combine(directory, "result.json"), JsonSerializer.Serialize(new
        {
            succeeded = true, title = window.Title, screenshots = files.Select(Path.GetFileName),
            urlValidation = true, sourceSwitch = true, mouseSourceSwitch = true,
            animatedSourceSwitch = true, reducedMotionSourceSwitch = true,
            dragSourceSwitch = true, keyboardSourceSwitch = true,
            accessibleSourceSwitch = true, keyboardFocus = focusWorks,
            note = "Capturas reais do XAML no runner. Não substitui teste manual no Windows 10/11."
        }, new JsonSerializerOptions { WriteIndented = true }));
    }
    private static async Task ClickSourceAsync(Window window, FrameworkElement root, SourceSelector selector,
        DownloadViewModel model, string name, DownloadSource expected)
    {
        var element = (FrameworkElement)selector.FindName(name);
        var point = element.TransformToVisual(root).TransformPoint(new Point(element.ActualWidth / 2, element.ActualHeight / 2));
        var scale = root.XamlRoot.RasterizationScale;
        var screen = new NativePoint { X = (int)(point.X * scale), Y = (int)(point.Y * scale) };
        var handle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        if (!ClientToScreen(handle, ref screen)) throw new InvalidOperationException("Não consegui localizar o seletor na tela.");
        SetForegroundWindow(handle);
        if (!SetCursorPos(screen.X, screen.Y)) throw new InvalidOperationException("Não consegui posicionar o mouse no teste.");
        await Task.Delay(30);
        var presses = selector.PointerPressCount;
        MouseInput[] inputs = [new() { Data = new() { Flags = 0x0002 } }, new() { Data = new() { Flags = 0x0004 } }];
        if (SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<MouseInput>()) != inputs.Length)
            throw new InvalidOperationException("O Windows não aceitou os cliques de teste.");
        await Task.Delay(60);
        if (selector.PointerPressCount <= presses) throw new InvalidOperationException("O clique não chegou ao seletor.");
        if (model.Source != expected)
            throw new InvalidOperationException($"Clique real em {name} não selecionou {expected}. " +
                $"PointerPressed {presses} -> {selector.PointerPressCount}; tela {screen.X},{screen.Y}; " +
                $"controle {element.ActualWidth}x{element.ActualHeight}; escala {scale}; " +
                $"janela ativa: {GetForegroundWindow() == handle}.");
    }
    private static async Task DragSourceAsync(Window window, FrameworkElement root, SourceSelector selector,
        DownloadViewModel model, bool backToVideo)
    {
        var source = (FrameworkElement)selector.FindName(backToVideo ? "SpotifyButton" : "YouTubeButton");
        var target = (FrameworkElement)selector.FindName(backToVideo ? "YouTubeButton" : "SpotifyButton");
        var handle = WinRT.Interop.WindowNative.GetWindowHandle(window);
        NativePoint Locate(FrameworkElement element)
        {
            var point = element.TransformToVisual(root).TransformPoint(new Point(element.ActualWidth / 2, element.ActualHeight / 2));
            var screen = new NativePoint { X = (int)(point.X * root.XamlRoot.RasterizationScale), Y = (int)(point.Y * root.XamlRoot.RasterizationScale) };
            if (!ClientToScreen(handle, ref screen)) throw new InvalidOperationException("Não consegui localizar a área do arraste.");
            return screen;
        }
        var from = Locate(source); var to = Locate(target);
        SetCursorPos(from.X, from.Y);
        await Task.Delay(40);
        MouseInput[] down = [new() { Data = new() { Flags = 0x0002 } }];
        MouseInput[] up = [new() { Data = new() { Flags = 0x0004 } }];
        if (SendInput(1, down, Marshal.SizeOf<MouseInput>()) != 1) throw new InvalidOperationException("Falha ao iniciar arraste.");
        try
        {
            await Task.Delay(40);
            for (var step = 1; step <= 6; step++)
            {
                // SetCursorPos repositions the cursor but does not reliably
                // produce captured WinUI pointer motion. Inject real moves.
                MoveMouseTo(new NativePoint { X = from.X + (to.X - from.X) * step / 6, Y = from.Y + (to.Y - from.Y) * step / 6 });
                await Task.Delay(40);
            }
        }
        finally { SendInput(1, up, Marshal.SizeOf<MouseInput>()); }
        await Task.Delay(350);
        if (model.Source != (backToVideo ? DownloadSource.Video : DownloadSource.Spotify))
            throw new InvalidOperationException($"Arrastar o indicador não trocou a origem (volta={backToVideo}; origem={model.Source}). {selector.PointerDiagnostics}");
    }
    private static void MoveMouseTo(NativePoint point)
    {
        var left = GetSystemMetrics(76); var top = GetSystemMetrics(77);
        var width = GetSystemMetrics(78); var height = GetSystemMetrics(79);
        MouseInput[] input = [new() { Data = new()
        {
            X = (int)Math.Round((point.X - left) * 65535.0 / (width - 1)),
            Y = (int)Math.Round((point.Y - top) * 65535.0 / (height - 1)),
            Flags = 0xC001 // MOVE | ABSOLUTE | VIRTUALDESK
        } }];
        if (SendInput(1, input, Marshal.SizeOf<MouseInput>()) != 1) throw new InvalidOperationException("Falha ao enviar movimento real do mouse.");
    }
    private static async Task PressKeyAsync(ushort key)
    {
        uint extended = key is 0x27 or 0x24 or 0x23 ? 1u : 0u;
        KeyboardInput[] inputs = [new() { Type = 1, Key = key, Flags = extended }, new() { Type = 1, Key = key, Flags = extended | 2 }];
        if (SendKeyboardInput(2, inputs, Marshal.SizeOf<KeyboardInput>()) != 2) throw new InvalidOperationException("Falha na entrada de teclado.");
        await Task.Delay(100);
    }
    // INPUT is 40 bytes for our x64-only target; KEYBDINPUT shares the union
    // with MOUSEINPUT at byte 8, with dwExtraInfo aligned at byte 24.
    [StructLayout(LayoutKind.Explicit, Size = 40)] private struct KeyboardInput
    {
        [FieldOffset(0)] public uint Type;
        [FieldOffset(8)] public ushort Key;
        [FieldOffset(12)] public uint Flags;
    }
    [DllImport("user32.dll", EntryPoint = "SendInput", ExactSpelling = true)]
    private static extern uint SendKeyboardInput(uint count, KeyboardInput[] inputs, int size);
    [StructLayout(LayoutKind.Sequential)] private struct NativePoint { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseData
    { public int X, Y; public uint Mouse, Flags, Time; public UIntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseInput { public uint Type; public MouseData Data; }
    [DllImport("user32.dll", SetLastError = true)] private static extern uint SendInput(uint count, MouseInput[] inputs, int size);
    [DllImport("user32.dll")] private static extern bool ClientToScreen(IntPtr window, ref NativePoint point);
    [DllImport("user32.dll")] private static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    private static void ToggleThroughAutomation(SourceSelector selector, string name)
    {
        var element = selector.FindName(name) as FrameworkElement ??
            throw new InvalidOperationException("O botão de origem não foi encontrado.");
        var peer = FrameworkElementAutomationPeer.CreatePeerForElement(element);
        if (peer.GetPattern(PatternInterface.SelectionItem) is not ISelectionItemProvider item)
            throw new InvalidOperationException("O seletor não expõe seu estado à automação de acessibilidade.");
        item.Select();
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
        var thumb = (FrameworkElement)selector.FindName("Thumb");
        var translation = thumb.RenderTransform as TranslateTransform ??
            throw new InvalidOperationException("O indicador não tem a transformação esperada.");
        var inner = (FrameworkElement)selector.FindName("Inner");
        var expectedOffset = selector.SelectedSource == DownloadSource.Video ? 0 : inner.ActualWidth / 2;
        if (Math.Abs(translation.X - expectedOffset) > 1)
            throw new InvalidOperationException($"O indicador roxo não acompanhou a origem: {translation.X}; esperado {expectedOffset}.");
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
