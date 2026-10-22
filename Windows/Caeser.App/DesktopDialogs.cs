using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.System;

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
        finally { desktopDialog = false; }
    }
    private async void History_Click(object sender, RoutedEventArgs e)
    {
        if (desktopDialog) return;
        desktopDialog = true;
        try
        {
            var list = new StackPanel { Spacing = 18, MinWidth = 340 };
            LibraryItem? retry = null;
            var dialog = new ContentDialog { XamlRoot = Root.XamlRoot, Title = "Histórico", CloseButtonText = "Concluído", SecondaryButtonText = "Limpar histórico…" };
            foreach (var item in ViewModel.History)
            {
                var row = new StackPanel { Spacing = 6 };
                row.Children.Add(new TextBlock { Text = item.Title, TextWrapping = TextWrapping.Wrap, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
                row.Children.Add(new TextBlock { Text = item.Detail, TextWrapping = TextWrapping.Wrap, Opacity = 0.75 });
                var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                var open = new Button { Content = "Abrir pasta" }; open.Click += (_, _) => { try { PlatformServices.Reveal(item.Request.Destination); } catch (Exception error) { ViewModel.ReportError(error.Message); } };
                var again = new Button { Content = item.State == QueueState.Completed ? "Baixar novamente" : "Tentar novamente" };
                again.Click += (_, _) => { retry = item; dialog.Hide(); };
                actions.Children.Add(open); actions.Children.Add(again); row.Children.Add(actions); list.Children.Add(row);
            }
            if (list.Children.Count == 0) list.Children.Add(new TextBlock { Text = "Seus últimos 100 downloads aparecem aqui." });
            dialog.Content = new ScrollViewer { Content = list, MaxHeight = 420 };
            var result = await dialog.ShowAsync();
            if (retry != null) ViewModel.Retry(retry);
            if (result == ContentDialogResult.Secondary)
            {
                var confirm = new ContentDialog { XamlRoot = Root.XamlRoot, Title = "Limpar histórico?", Content = "Só os registros serão removidos. Seus arquivos baixados continuam na pasta.", PrimaryButtonText = "Limpar histórico", CloseButtonText = "Cancelar", DefaultButton = ContentDialogButton.Close };
                if (await confirm.ShowAsync() == ContentDialogResult.Primary) ViewModel.ClearHistory();
            }
        }
        finally { desktopDialog = false; }
    }
}
