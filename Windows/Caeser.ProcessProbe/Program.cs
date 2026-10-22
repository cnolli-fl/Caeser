using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace Caeser.ProcessProbe;

public static class ProbeMarker
{
    public static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        switch (args.FirstOrDefault())
        {
            case "echo":
                Console.WriteLine(JsonSerializer.Serialize(new { arguments = args.Skip(1), directory = Environment.CurrentDirectory }));
                return 0;
            case "utf8":
                var bytes = Encoding.UTF8.GetBytes("ação 🎵 日本語\rprogresso 20%\r\núltima linha sem quebra");
                var stream = Console.OpenStandardOutput();
                foreach (var value in bytes) await stream.WriteAsync(new[] { value });
                return 0;
            case "flood":
                await Task.WhenAll(Task.Run(() =>
                {
                    for (var i = 0; i < 2000; i++) Console.WriteLine($"out:{i}");
                }), Task.Run(() =>
                {
                    for (var i = 0; i < 2000; i++) Console.Error.WriteLine($"err:{i}");
                }));
                return 0;
            case "long":
                Console.WriteLine(new string('x', 100_000));
                Console.WriteLine("fim"); return 0;
            case "sleep-tree":
            case "orphan":
                var childInfo = new ProcessStartInfo(Environment.ProcessPath!) { UseShellExecute = false };
                foreach (var arg in new[] { "exec", "--runtimeconfig", args[1], typeof(ProbeMarker).Assembly.Location, "child" })
                    childInfo.ArgumentList.Add(arg);
                using (var child = Process.Start(childInfo)!)
                {
                    Console.WriteLine($"child:{child.Id}");
                    if (args[0] == "orphan") return 0;
                    await Task.Delay(TimeSpan.FromMinutes(5));
                }
                return 0;
            case "child": await Task.Delay(TimeSpan.FromMinutes(5)); return 0;
            case "exit": return int.Parse(args[1]);
            default: return 2;
        }
    }
}
