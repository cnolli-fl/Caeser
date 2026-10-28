using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.System;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Text;

namespace Caeser.App;
public sealed partial class MainWindow
{
    private bool desktopDialog;
    private CancellationTokenSource? updateCancellation;
    private void Pause_Click(object sender, RoutedEventArgs e) => ViewModel.TogglePause();
    private void CancelCurrent_Click(object sender, RoutedEventArgs e) => ViewModel.Cancel();
    private void QueueUp_Click(object sender, RoutedEventArgs e) { if (((MenuFlyoutItem)sender).Tag is LibraryItem item) ViewModel.Move(item, -1); }
    private void QueueDown_Click(object sender, RoutedEventArgs e) { if (((MenuFlyoutItem)sender).Tag is LibraryItem item) ViewModel.Move(item, 1); }
    private void QueueRemove_Click(object sender, RoutedEventArgs e) { if (((MenuFlyoutItem)sender).Tag is LibraryItem item) ViewModel.Remove(item); }
    private async void Match_Click(object sender, RoutedEventArgs e)
    { if (ViewModel.Preview?.MatchedUrl is { } url && PreviewService.IsYouTube(url)) await Launcher.LaunchUriAsync(url); }
    private async void Updates_Click(object sender, RoutedEventArgs e)
    {
        if (desktopDialog) return;
        desktopDialog = true;
        try
        {
            await ViewModel.CheckUpdatesAsync(true);
            var update = ViewModel.Update;
            var installation = InstalledDirectory();
            var automatic = update?.CanInstall == true && installation != null;
            var dialog = new ContentDialog { XamlRoot = Root.XamlRoot, RequestedTheme = Root.ActualTheme, Title = "Atualizações do Caeser",
                Content = ViewModel.UpdateMessage + (update == null ? "" : automatic
                    ? "\nBaixe a atualização por aqui e escolha quando instalar e reiniciar. Sua fila, histórico e preferências serão preservados."
                    : "\nEsta versão ou cópia portátil requer instalação manual. Abra o instalador oficial pela página da release."),
                CloseButtonText = update != null ? "Depois" : "Concluído", PrimaryButtonText = update != null ? automatic ? "Baixar no aplicativo" : "Abrir download" : "",
                SecondaryButtonText = update != null ? "Ver novidades" : "" };
            var result = await dialog.ShowAsync();
            if (update != null && result != ContentDialogResult.None)
            {
                if (result == ContentDialogResult.Primary && automatic)
                {
                    if (ViewModel.IsBusy) ViewModel.ReportError("Espere o download atual terminar antes de atualizar.");
                    else await DownloadUpdateAsync(update, installation!);
                }
                else await Launcher.LaunchUriAsync(result == ContentDialogResult.Primary ? update.Download : update.Page);
            }
        }
        catch (Exception error) { ViewModel.ReportError("Não consegui abrir a atualização: " + error.Message); }
        finally { desktopDialog = false; }
    }
    private static string? InstalledDirectory()
    {
        try
        {
            var application = new DirectoryInfo(AppContext.BaseDirectory);
            if (application.Name != "Aplicativo" || application.Parent is not { } parent) return null;
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\{8362D1BB-D499-462E-9633-409161F21111}_is1");
            var registered = key?.GetValue("InstallLocation") as string;
            return registered != null && Path.GetFullPath(registered).TrimEnd(Path.DirectorySeparatorChar).Equals(parent.FullName, StringComparison.OrdinalIgnoreCase)
                && File.Exists(Path.Combine(parent.FullName, "Caeser.exe")) ? parent.FullName : null;
        }
        catch { return null; }
    }
    private async Task DownloadUpdateAsync(ReleaseUpdate update, string installation)
    {
        using var cancellation = new CancellationTokenSource(); updateCancellation = cancellation;
        var dialog = CreateUpdateDownloadDialog(update.Version, out var message, out var progress);
        string? path = null; bool launched = false, dismissed = false, ready = false;
        var shown = dialog.ShowAsync().AsTask();
        try
        {
            var transfer = new UpdateInstaller().DownloadAsync(update, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Caeser", "Updates"),
                new Progress<double>(value => { if (!dismissed && !ready) { progress.Value = value; message.Text = value >= 100 ? "Conferindo integridade…" : $"Baixando atualização · {value:0}%"; } }), cancellation.Token);
            if (await Task.WhenAny(transfer, shown) == shown) cancellation.Cancel();
            path = await transfer;
            if (cancellation.IsCancellationRequested || shown.IsCompleted) return;
            ready = true;
            message.Text = UpdateReadyMessage;
            progress.Value = 100; dialog.IsPrimaryButtonEnabled = true; dialog.CloseButtonText = "Depois";
            if (await shown == ContentDialogResult.Primary)
            {
                ViewModel.PauseForUpdate();
                await UpdateInstaller.LaunchAsync(path, installation, update);
                launched = true; allowClose = true; Close();
            }
        }
        catch (OperationCanceledException)
        {
            if (!shown.IsCompleted && !cancellation.IsCancellationRequested)
            { message.Text = "A atualização demorou demais. Tente novamente quando sua conexão melhorar."; progress.Visibility = Visibility.Collapsed; dialog.CloseButtonText = "Fechar"; await shown; }
        }
        catch (Exception error)
        {
            if (!shown.IsCompleted)
            {
                message.Text = "Não consegui concluir a atualização. Nada foi instalado. " + error.Message;
                progress.Visibility = Visibility.Collapsed; dialog.IsPrimaryButtonEnabled = false; dialog.CloseButtonText = "Fechar"; await shown;
            }
            else ViewModel.ReportError("Não consegui iniciar a instalação. " + error.Message);
        }
        finally
        {
            dismissed = true; cancellation.Cancel(); updateCancellation = null;
            if (!shown.IsCompleted) { dialog.Hide(); await shown; }
            if (path != null && !launched) UpdateInstaller.DeleteDownload(path);
        }
    }
    internal const string UpdateReadyMessage = "Atualização pronta. Ao instalar, o Caeser será fechado e aberto novamente. Sua fila será preservada e voltará pausada.";
    internal ContentDialog CreateUpdateDownloadDialog(string version, out TextBlock message, out ProgressBar progress)
    {
        message = new TextBlock { Text = "Baixando a atualização…", TextWrapping = TextWrapping.Wrap, MaxWidth = 400 };
        progress = new ProgressBar { Minimum = 0, Maximum = 100, Value = 0 };
        AutomationProperties.SetName(progress, "Download da atualização");
        var body = new StackPanel { Spacing = 16, MinWidth = 300 }; body.Children.Add(message); body.Children.Add(progress);
        return new ContentDialog { XamlRoot = Root.XamlRoot, RequestedTheme = Root.ActualTheme, Title = $"Caeser {version}",
            Content = body, CloseButtonText = "Cancelar", PrimaryButtonText = "Instalar e reiniciar", IsPrimaryButtonEnabled = false };
    }
    private async void History_Click(object sender, RoutedEventArgs e)
    {
        if (desktopDialog) return;
        desktopDialog = true;
        try
        {
            LibraryItem? retry = null;
            var dialog = CreateHistoryDialog(ViewModel.History.ToArray(), item => retry = item);
            var result = await dialog.ShowAsync();
            if (retry != null) ViewModel.Retry(retry);
            if (result == ContentDialogResult.Secondary)
            {
                var confirm = new ContentDialog { XamlRoot = Root.XamlRoot, Title = "Limpar histórico?", Content = "Só os registros serão removidos. Seus arquivos baixados continuam na pasta.", PrimaryButtonText = "Limpar histórico", CloseButtonText = "Cancelar", DefaultButton = ContentDialogButton.Close };
                if (await confirm.ShowAsync() == ContentDialogResult.Primary) ViewModel.ClearHistory();
            }
        }
        catch (Exception error) { ViewModel.ReportError("Não consegui abrir o histórico: " + error.Message); }
        finally { desktopDialog = false; }
    }

    internal ContentDialog CreateHistoryDialog(IReadOnlyList<LibraryItem> items, Action<LibraryItem> retry)
    {
        var dialog = new ContentDialog { XamlRoot = Root.XamlRoot, RequestedTheme = Root.ActualTheme, Title = "Histórico", CloseButtonText = "Fechar",
            SecondaryButtonText = items.Count > 0 ? "Limpar histórico…" : "", DefaultButton = ContentDialogButton.Close };
        dialog.Resources["ContentDialogMaxWidth"] = 620d;
        TextBlock Secondary(string value)
        {
            var text = (TextBlock)Microsoft.UI.Xaml.Markup.XamlReader.Load("<TextBlock xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Foreground='{ThemeResource TextFillColorSecondaryBrush}' FontSize='13' />");
            text.Text = value; return text;
        }
        var body = new StackPanel { Spacing = 16, Width = Math.Min(548, Math.Max(240, Root.ActualWidth - 96)) };
        var subtitle = Secondary(items.Count == 0 ? "Seus últimos downloads, salvos neste PC." : $"{items.Count} de 100 registros · salvos neste PC");
        subtitle.FontSize = 14; subtitle.TextWrapping = TextWrapping.Wrap; body.Children.Add(subtitle);
        var list = new StackPanel();
        foreach (var item in items)
        {
            var row = new Grid { ColumnSpacing = 12, Padding = new Thickness(0, 14, 0, 14) };
            row.ColumnDefinitions.Add(new() { Width = GridLength.Auto });
            row.ColumnDefinitions.Add(new() { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new() { Width = GridLength.Auto });
            var symbol = item.State switch { QueueState.Completed => Symbol.Accept, QueueState.Failed => Symbol.Important, _ => Symbol.Pause };
            var icon = new FontIcon { Glyph = item.Request.Source == DownloadSource.Spotify ? "\uE8D6" : "\uE714", FontSize = 20,
                Width = 36, VerticalAlignment = VerticalAlignment.Center };
            AutomationProperties.SetAccessibilityView(icon, Microsoft.UI.Xaml.Automation.Peers.AccessibilityView.Raw);
            row.Children.Add(icon);
            var text = new StackPanel { Spacing = 5, VerticalAlignment = VerticalAlignment.Center };
            var title = new TextBlock { Text = item.Title, FontSize = 14, FontWeight = FontWeights.SemiBold,
                MaxLines = 2, TextWrapping = TextWrapping.Wrap, TextTrimming = TextTrimming.CharacterEllipsis };
            ToolTipService.SetToolTip(title, item.Title); text.Children.Add(title);
            var status = item.State switch { QueueState.Completed => "Concluído", QueueState.Failed => "Não concluído", QueueState.Cancelled => "Cancelado", _ => "Interrompido ao fechar" };
            var meta = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            meta.Children.Add(new SymbolIcon(symbol) { Width = 16, Height = 16 });
            meta.Children.Add(Secondary($"{status} · {item.Created.ToLocalTime():dd/MM HH:mm}"));
            text.Children.Add(meta);
            if (item.State is QueueState.Failed or QueueState.Interrupted)
            {
                var detail = Secondary(item.Detail); detail.MaxLines = 1; detail.TextTrimming = TextTrimming.CharacterEllipsis;
                ToolTipService.SetToolTip(detail, item.Detail); text.Children.Add(detail);
            }
            Grid.SetColumn(text, 1); row.Children.Add(text);
            var actions = new StackPanel { Name = "HistoryActions", Orientation = Orientation.Horizontal, Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
            Button ActionButton(Symbol glyph, string label)
            {
                var mark = (SymbolIcon)Microsoft.UI.Xaml.Markup.XamlReader.Load("<SymbolIcon xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Foreground='{ThemeResource CaeserForeground}' />");
                mark.Symbol = glyph;
                var button = new Button { Content = mark, Width = 36, Height = 36, Padding = new Thickness(6),
                    Style = (Style)Application.Current.Resources["SubtleButtonStyle"] };
                AutomationProperties.SetName(button, label); ToolTipService.SetToolTip(button, label); return button;
            }
            var open = ActionButton(Symbol.Folder, "Abrir pasta");
            open.Click += (_, _) => { try { PlatformServices.Reveal(item.Request.Destination); } catch (Exception error) { ViewModel.ReportError(error.Message); } };
            var again = ActionButton(Symbol.Refresh, item.State == QueueState.Completed ? "Baixar novamente" : "Tentar novamente");
            again.Click += (_, _) => { retry(item); dialog.Hide(); };
            actions.Children.Add(open); actions.Children.Add(again); Grid.SetColumn(actions, 2); row.Children.Add(actions);
            list.Children.Add(row);
            if (item != items.Last())
            {
                var divider = (Border)Microsoft.UI.Xaml.Markup.XamlReader.Load("<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Background='{ThemeResource DividerStrokeColorDefaultBrush}' Height='1' Margin='48,0,0,0' />");
                list.Children.Add(divider);
            }
        }
        if (items.Count == 0)
        {
            var empty = new StackPanel { Spacing = 12, Padding = new Thickness(24, 32, 24, 32), HorizontalAlignment = HorizontalAlignment.Center };
            empty.Children.Add(new SymbolIcon(Symbol.Clock) { Width = 32, Height = 32 });
            empty.Children.Add(new TextBlock { Text = "Nenhum download ainda", FontSize = 16, FontWeight = FontWeights.SemiBold, TextAlignment = TextAlignment.Center });
            var description = Secondary("Os downloads concluídos, cancelados ou com erro aparecem aqui.");
            description.MaxWidth = 320; description.TextWrapping = TextWrapping.Wrap;
            description.TextAlignment = TextAlignment.Center; description.FontSize = 14; empty.Children.Add(description);
            list.Children.Add(empty);
        }
        body.Children.Add(new ScrollViewer { Content = list, MaxHeight = Math.Max(160, Math.Min(360, Root.ActualHeight - 260)),
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalContentAlignment = HorizontalAlignment.Stretch });
        dialog.Content = body;
        return dialog;
    }
}
