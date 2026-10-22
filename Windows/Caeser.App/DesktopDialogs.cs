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
            var dialog = new ContentDialog { XamlRoot = Root.XamlRoot, Title = "Atualizações do Caeser",
                Content = ViewModel.UpdateMessage + (update != null ? "\nBaixe o instalador oficial e feche o Caeser antes de instalar. Sua fila, histórico e preferências ficam preservados." : ""),
                CloseButtonText = update != null ? "Depois" : "Concluído", PrimaryButtonText = update != null ? "Baixar atualização" : "",
                SecondaryButtonText = update != null ? "Ver novidades" : "" };
            var result = await dialog.ShowAsync();
            if (update != null && result != ContentDialogResult.None)
                await Launcher.LaunchUriAsync(result == ContentDialogResult.Primary ? update.Download : update.Page);
        }
        catch (Exception error) { ViewModel.ReportError("Não consegui abrir a atualização: " + error.Message); }
        finally { desktopDialog = false; }
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
        var body = new StackPanel { Spacing = 16, Width = Math.Min(548, Math.Max(240, Root.ActualWidth - 96)) };
        body.Children.Add(new TextBlock { Text = items.Count == 0 ? "Seus últimos downloads, salvos neste PC." : $"{items.Count} de 100 registros · salvos neste PC",
            FontSize = 14, Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"], TextWrapping = TextWrapping.Wrap });
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
            meta.Children.Add(new TextBlock { Text = $"{status} · {item.Created.ToLocalTime():dd/MM HH:mm}", FontSize = 13,
                Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"] });
            text.Children.Add(meta);
            if (item.State is QueueState.Failed or QueueState.Interrupted)
            {
                var detail = new TextBlock { Text = item.Detail, FontSize = 13, MaxLines = 1, TextTrimming = TextTrimming.CharacterEllipsis,
                    Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"] };
                ToolTipService.SetToolTip(detail, item.Detail); text.Children.Add(detail);
            }
            Grid.SetColumn(text, 1); row.Children.Add(text);
            var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
            Button ActionButton(Symbol glyph, string label)
            {
                var button = new Button { Content = new SymbolIcon(glyph), Width = 36, Height = 36, Padding = new Thickness(6),
                    Style = (Style)Application.Current.Resources["SubtleButtonStyle"] };
                AutomationProperties.SetName(button, label); ToolTipService.SetToolTip(button, label); return button;
            }
            var open = ActionButton(Symbol.Folder, "Abrir pasta");
            open.Click += (_, _) => { try { PlatformServices.Reveal(item.Request.Destination); } catch (Exception error) { ViewModel.ReportError(error.Message); } };
            var again = ActionButton(Symbol.Refresh, item.State == QueueState.Completed ? "Baixar novamente" : "Tentar novamente");
            again.Click += (_, _) => { retry(item); dialog.Hide(); };
            actions.Children.Add(open); actions.Children.Add(again); Grid.SetColumn(actions, 2); row.Children.Add(actions);
            list.Children.Add(row);
            if (item != items.Last()) list.Children.Add(new Border { Height = 1, Margin = new Thickness(48, 0, 0, 0),
                Background = (Brush)Application.Current.Resources["DividerStrokeColorDefaultBrush"] });
        }
        if (items.Count == 0)
        {
            var empty = new StackPanel { Spacing = 12, Padding = new Thickness(24, 32, 24, 32), HorizontalAlignment = HorizontalAlignment.Center };
            empty.Children.Add(new SymbolIcon(Symbol.Clock) { Width = 32, Height = 32 });
            empty.Children.Add(new TextBlock { Text = "Nenhum download ainda", FontSize = 16, FontWeight = FontWeights.SemiBold, TextAlignment = TextAlignment.Center });
            empty.Children.Add(new TextBlock { Text = "Os downloads concluídos, cancelados ou com erro aparecem aqui.", MaxWidth = 320,
                TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center, FontSize = 14,
                Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"] });
            list.Children.Add(empty);
        }
        body.Children.Add(new ScrollViewer { Content = list, MaxHeight = Math.Max(160, Math.Min(360, Root.ActualHeight - 260)),
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalContentAlignment = HorizontalAlignment.Stretch });
        dialog.Content = body;
        return dialog;
    }
}
