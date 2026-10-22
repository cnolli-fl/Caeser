using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using Windows.ApplicationModel.DataTransfer;

namespace Caeser.App;

internal static class PlatformServices
{
    public static string DownloadsPath()
    {
        var id = new Guid("374DE290-123F-4565-9164-39C4925E467B");
        if (SHGetKnownFolderPath(ref id, 0, IntPtr.Zero, out var pointer) == 0)
        {
            try { return Marshal.PtrToStringUni(pointer)!; }
            finally { Marshal.FreeCoTaskMem(pointer); }
        }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
    }
    public static async Task<string?> PickFolderAsync(Window window)
    {
        var picker = new Microsoft.Windows.Storage.Pickers.FolderPicker(window.AppWindow.Id)
        { CommitButtonText = "Salvar nesta pasta" };
        return (await picker.PickSingleFolderAsync())?.Path;
    }
    public static async Task<string?> PasteAsync()
    {
        var content = Clipboard.GetContent();
        return content.Contains(StandardDataFormats.Text) ? (await content.GetTextAsync()).Trim() : null;
    }
    public static void Copy(string text)
    {
        var content = new DataPackage();
        content.SetText(text); Clipboard.SetContent(content);
    }
    public static void Reveal(string path)
    {
        if (!Directory.Exists(path)) throw new IOException("A pasta não está mais disponível. Confira o destino.");
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true, Verb = "open" });
    }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHGetKnownFolderPath(ref Guid folder, uint flags, IntPtr token, out IntPtr path);
}
