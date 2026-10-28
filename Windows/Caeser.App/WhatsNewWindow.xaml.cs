using Caeser.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Windows.Graphics;
using Windows.System;

namespace Caeser.App;

public sealed partial class WhatsNewWindow : Window
{
    private readonly WhatsNewStore store;
    public WhatsNewWindow(WhatsNewStore store)
    {
        this.store = store;
        InitializeComponent();
        VersionLabel.Text = "Caeser para Windows · " + store.VersionText;
        Highlights.ItemsSource = store.Highlights;
        NotesLink.NavigateUri = store.NotesUrl;
        AppWindow.Resize(new SizeInt32(560, 570));
        AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "Caeser.ico"));
        NotesRoot.KeyboardAccelerators.Add(new KeyboardAccelerator { Key = VirtualKey.Escape });
        foreach (var accelerator in NotesRoot.KeyboardAccelerators)
            accelerator.Invoked += (_, e) => { e.Handled = true; Close(); };
    }
    private void Notes_Loaded(object sender, RoutedEventArgs e)
    {
        try { store.MarkPresented(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { /* A preferences write failure must never prevent opening the downloader. */ }
        ContinueButton.Focus(FocusState.Programmatic);
    }
    private void Continue_Click(object sender, RoutedEventArgs e) => Close();
}
