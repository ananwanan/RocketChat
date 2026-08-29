using System.Windows;

namespace RocketChat.Client;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        DispatcherUnhandledException += (_, args) =>
        {
            MessageBox.Show(args.Exception.Message, "Rocket.Chat 客户端", MessageBoxButton.OK, MessageBoxImage.Error);
            args.Handled = true;
        };
    }
}
