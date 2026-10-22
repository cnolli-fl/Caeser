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
        try
        {
            // Use the Windows App SDK API: the similarly named UWP API
            // requires package identity and fails in this unpackaged app.
            Microsoft.Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride = "pt-BR";
            System.Globalization.CultureInfo.DefaultThreadCurrentUICulture = System.Globalization.CultureInfo.GetCultureInfo("pt-BR");
            InitializeComponent();
        }
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
        // Normal launches need a useful report too. Never suppress an unknown
        // XAML exception: record it without pretending that the app recovered.
        try
        {
            var logs = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Caeser", "Logs");
            Directory.CreateDirectory(logs);
            File.WriteAllText(Path.Combine(logs, "ultima-falha.txt"),
                $"Caeser {typeof(App).Assembly.GetName().Version} · {DateTimeOffset.Now:O}{Environment.NewLine}{error}");
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        var args = Environment.GetCommandLineArgs();
        var index = Array.IndexOf(args, "--smoke-test");
        if (index < 0 || index + 1 >= args.Length) return;
        try
        {
            var directory = Path.GetFullPath(args[index + 1]);
            Directory.CreateDirectory(directory);
            var details = new System.Text.StringBuilder(error.ToString());
            for (Exception? current = error; current != null; current = current.InnerException)
            {
                details.AppendLine().AppendLine($"HRESULT: 0x{current.HResult:X8}");
                foreach (System.Collections.DictionaryEntry entry in current.Data)
                    if (entry.Value is string value)
                        details.AppendLine($"{entry.Key}: {value}");
            }
            var message = details.ToString();
            File.WriteAllText(Path.Combine(directory, "startup-error.txt"), message);
            File.WriteAllText(Path.Combine(directory, "result.json"),
                JsonSerializer.Serialize(new { succeeded = false, error = message }));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
