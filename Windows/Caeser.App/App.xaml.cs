using Microsoft.UI.Xaml;
using System.Text.Json;

namespace Caeser.App;

public partial class App : Application
{
    private MainWindow? window;
    public App()
    {
        UnhandledException += (_, e) => RecordStartupFailure(e.Exception);
        if (Environment.GetCommandLineArgs().Contains("--smoke-test"))
        {
            DebugSettings.IsXamlResourceReferenceTracingEnabled = true;
            DebugSettings.XamlResourceReferenceFailed += (_, e) => RecordTrace(e.Message);
            DebugSettings.IsBindingTracingEnabled = true;
            DebugSettings.BindingFailed += (_, e) => RecordTrace(e.Message);
        }
        try { InitializeComponent(); }
        catch (Exception e) { RecordStartupFailure(e); throw; }
    }
    private static void RecordTrace(string message)
    {
        var args = Environment.GetCommandLineArgs();
        var index = Array.IndexOf(args, "--smoke-test");
        if (index < 0 || index + 1 >= args.Length) return;
        try
        {
            var directory = Path.GetFullPath(args[index + 1]);
            Directory.CreateDirectory(directory);
            var path = Path.Combine(directory, "xaml-diagnostics.txt");
            if (!File.Exists(path) || new FileInfo(path).Length < 262144)
                File.AppendAllText(path, message + Environment.NewLine);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            window = new MainWindow();
            window.Activate();
        }
        catch (Exception e) { RecordStartupFailure(e); throw; }
    }
    private static void RecordStartupFailure(Exception error)
    {
        var args = Environment.GetCommandLineArgs();
        var index = Array.IndexOf(args, "--smoke-test");
        if (index < 0 || index + 1 >= args.Length) return;
        try
        {
            var directory = Path.GetFullPath(args[index + 1]);
            Directory.CreateDirectory(directory);
            File.WriteAllText(Path.Combine(directory, "startup-error.txt"), error.ToString());
            File.WriteAllText(Path.Combine(directory, "result.json"),
                JsonSerializer.Serialize(new { succeeded = false, error = error.ToString() }));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
