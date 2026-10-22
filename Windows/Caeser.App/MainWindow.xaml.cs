using System.ComponentModel;
using Caeser.App.ViewModels;
using Caeser.Core;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.Graphics;
using Windows.System;

namespace Caeser.App;

public sealed partial class MainWindow : Window
{
    public DownloadViewModel ViewModel { get; }
    private bool allowClose, closingPrompt, loaded;

    public MainWindow()
    {
        InitializeComponent();
        ViewModel = new(DispatcherQueue);
        Root.DataContext = ViewModel;
        ViewModel.PropertyChanged += ViewModel_Changed;
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(DragRegion);
        AppWindow.Resize(new SizeInt32(860, 850));
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "Caeser.ico"));
        AppWindow.Closing += Window_Closing;
    }
    private async void Root_Loaded(object sender, RoutedEventArgs e)
    {
        if (loaded) return;
        loaded = true;
        UrlBox.Focus(FocusState.Programmatic);
        if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 19045))
            ViewModel.ReportError("Esta versão requer Windows 10 22H2 ou Windows 11, de 64 bits.");
        var args = Environment.GetCommandLineArgs();
        var index = Array.IndexOf(args, "--smoke-test");
        if (index >= 0 && index + 1 < args.Length)
        {
            try { await UiSmokeTest.RunAsync(this, Root, SourceBar, UrlBox, ViewModel, args[index + 1]); }
            catch (Exception error) { await UiSmokeTest.RecordFailureAsync(args[index + 1], error); }
            allowClose = true;
            Close();
        }
    }
    private void Root_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (FormatPanel == null) return;
        var compact = e.NewSize.Width < 700;
        Grid.SetColumn(FormatPanel, compact ? 0 : 1);
        Grid.SetRow(FormatPanel, compact ? 1 : 0);
        Grid.SetColumnSpan(FormatPanel, compact ? 2 : 1);
        CaptionInset.Width = new GridLength(144);
    }
    private void ViewModel_Changed(object? sender, PropertyChangedEventArgs e)
    {
        if (SourceBar.SelectedSource != ViewModel.Source) SourceBar.SelectedSource = ViewModel.Source;
    }
    private void Source_Changed(object? sender, EventArgs e)
    {
        if (ViewModel != null) ViewModel.Source = SourceBar.SelectedSource;
    }
    private async void Download_Click(object sender, RoutedEventArgs e)
    { if (ViewModel.IsBusy) ViewModel.Cancel(); else await ViewModel.StartAsync(); }
    private async void DownloadShortcut(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs e)
    { e.Handled = true; if (!ViewModel.IsBusy) await ViewModel.StartAsync(); }
    private void LinkShortcut(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs e)
    { if (ViewModel.IsBusy) return; UrlBox.Focus(FocusState.Keyboard); UrlBox.SelectAll(); e.Handled = true; }
    private void CancelShortcut(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs e)
    { if (ViewModel.IsBusy) { ViewModel.Cancel(); e.Handled = true; } }
    private async void Url_KeyDown(object sender, KeyRoutedEventArgs e)
    { if (e.Key == VirtualKey.Enter && !ViewModel.IsBusy) { e.Handled = true; await ViewModel.StartAsync(); } }
    private async void Paste_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (await PlatformServices.PasteAsync() is { } value) ViewModel.UrlText = value;
            UrlBox.Focus(FocusState.Programmatic);
        }
        catch (Exception error) { ViewModel.ReportError("Não consegui acessar a área de transferência: " + error.Message); }
    }
    private async void Folder_Click(object sender, RoutedEventArgs e)
    {
        try { if (await PlatformServices.PickFolderAsync(this) is { } path) ViewModel.ChooseDestination(path); }
        catch (Exception error) { ViewModel.ReportError("Não consegui abrir a seleção de pasta: " + error.Message); }
    }
    private void Reveal_Click(object sender, RoutedEventArgs e)
    {
        try { if (ViewModel.LastDestination != null) PlatformServices.Reveal(ViewModel.LastDestination); }
        catch (Exception error) { ViewModel.ReportError("Não consegui abrir a pasta: " + error.Message); }
    }
    private void Verify_Click(object sender, RoutedEventArgs e) => ViewModel.RefreshTools();
    private void Clear_Click(object sender, RoutedEventArgs e) => ViewModel.ClearLogs();
    private void Copy_Click(object sender, RoutedEventArgs e)
    {
        try { PlatformServices.Copy(ViewModel.Logs); }
        catch (Exception error) { ViewModel.ReportError("Não consegui copiar o registro: " + error.Message); }
    }
    private async void Window_Closing(AppWindow sender, AppWindowClosingEventArgs e)
    {
        if (allowClose || !ViewModel.IsBusy) return;
        e.Cancel = true;
        if (closingPrompt) return;
        closingPrompt = true;
        try
        {
            var dialog = new ContentDialog
            {
                XamlRoot = Root.XamlRoot, Title = "Cancelar o download e sair?",
                Content = "O download em andamento será interrompido. Os arquivos já salvos não serão apagados.",
                PrimaryButtonText = "Cancelar download e sair", CloseButtonText = "Continuar baixando",
                DefaultButton = ContentDialogButton.Close
            };
            if (await dialog.ShowAsync() == ContentDialogResult.Primary)
            {
                await ViewModel.CancelAndWaitAsync();
                allowClose = true; Close();
            }
        }
        finally { closingPrompt = false; }
    }
}
