using System.Windows;
using System.Windows.Controls;

namespace RocketChat.Client;

internal static class InputDialog
{
    public static string? Show(Window owner, string title, string label, string initial = "")
    {
        var box = new TextBox { Text = initial, MinWidth = 330, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 70 };
        var ok = new Button { Content = "确定", IsDefault = true, MinWidth = 72, Margin = new(8, 0, 0, 0) };
        var cancel = new Button { Content = "取消", IsCancel = true, MinWidth = 72, Margin = new(8, 0, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new(0, 14, 0, 0) }; buttons.Children.Add(cancel); buttons.Children.Add(ok);
        var panel = new StackPanel { Margin = new(18) }; panel.Children.Add(new TextBlock { Text = label, Margin = new(0, 0, 0, 7) }); panel.Children.Add(box); panel.Children.Add(buttons);
        var dialog = new Window { Owner = owner, Title = title, Content = panel, SizeToContent = SizeToContent.WidthAndHeight, ResizeMode = ResizeMode.NoResize, WindowStartupLocation = WindowStartupLocation.CenterOwner, ShowInTaskbar = false };
        ok.Click += (_, _) => dialog.DialogResult = true; box.SelectAll(); box.Focus();
        return dialog.ShowDialog() == true ? box.Text : null;
    }
}

internal enum NewConversationKind { Direct, PublicChannel, PrivateChannel }
internal sealed record NewConversationChoice(NewConversationKind Kind, string Name);
internal static class NewConversationDialog
{
    public static NewConversationChoice? Show(Window owner)
    {
        var type = new ComboBox { ItemsSource = new[] { "私信", "公开频道", "私有频道" }, SelectedIndex = 0, MinWidth = 330, Margin = new(0, 0, 0, 12) };
        var name = new TextBox { MinWidth = 330 };
        var ok = new Button { Content = "创建", IsDefault = true, MinWidth = 72, Margin = new(8, 0, 0, 0) };
        var cancel = new Button { Content = "取消", IsCancel = true, MinWidth = 72, Margin = new(8, 0, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new(0, 14, 0, 0) }; buttons.Children.Add(cancel); buttons.Children.Add(ok);
        var panel = new StackPanel { Margin = new(18) }; panel.Children.Add(new TextBlock { Text = "类型", Margin = new(0, 0, 0, 7) }); panel.Children.Add(type); panel.Children.Add(new TextBlock { Text = "用户名或频道名", Margin = new(0, 0, 0, 7) }); panel.Children.Add(name); panel.Children.Add(buttons);
        var dialog = new Window { Owner = owner, Title = "新建会话", Content = panel, SizeToContent = SizeToContent.WidthAndHeight, ResizeMode = ResizeMode.NoResize, WindowStartupLocation = WindowStartupLocation.CenterOwner, ShowInTaskbar = false };
        ok.Click += (_, _) => { if (!string.IsNullOrWhiteSpace(name.Text)) dialog.DialogResult = true; }; name.Focus();
        if (dialog.ShowDialog() != true) return null;
        return new((NewConversationKind)type.SelectedIndex, name.Text.Trim().TrimStart('@'));
    }
}
