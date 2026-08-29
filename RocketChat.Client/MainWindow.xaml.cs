using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;

namespace RocketChat.Client;

public partial class MainWindow : Window
{
    private readonly RocketChatApi _api = new();
    private readonly RealtimeClient _realtime = new();
    private readonly ObservableCollection<Room> _rooms = [];
    private readonly ObservableCollection<ChatMessage> _messages = [];
    private ICollectionView? _roomView;
    private Room? _room;
    private ChatMessage? _replyTo;
    private CancellationTokenSource? _loadCts;
    private string _workspace = "Rocket.Chat";

    public MainWindow()
    {
        InitializeComponent();
        RoomList.ItemsSource = _rooms;
        MessageList.ItemsSource = _messages;
        _roomView = CollectionViewSource.GetDefaultView(_rooms);
        _roomView.Filter = FilterRoom;
        _realtime.MessageReceived += Realtime_MessageReceived;
        _realtime.ConnectionChanged += (_, text) => Dispatcher.Invoke(() => RealtimeStatus.Text = text);
        Closing += MainWindow_Closing;
    }

    private async void LoginButton_Click(object sender, RoutedEventArgs e) => await LoginAsync();
    private async void PasswordBox_KeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Enter) { e.Handled = true; await LoginAsync(); } }

    private async Task LoginAsync()
    {
        LoginStatus.Text = "正在连接…"; LoginButton.IsEnabled = false;
        try
        {
            var info = await _api.GetServerInfoAsync(ServerBox.Text);
            _workspace = string.IsNullOrWhiteSpace(info.Name) ? new Uri(ServerBox.Text).Host : info.Name;
            var session = await _api.LoginAsync(ServerBox.Text, UsernameBox.Text, PasswordBox.Password);
            PasswordBox.Clear();
            WorkspaceName.Text = _workspace; CurrentUser.Text = $"● {session.DisplayName}  @{session.Username}";
            LoginView.Visibility = Visibility.Collapsed; ChatView.Visibility = Visibility.Visible;
            await RefreshRoomsAsync();
            try { await _realtime.ConnectAsync(_api.ServerUri!, session); }
            catch (Exception ex) { RealtimeStatus.Text = $"定时刷新模式：{ex.Message}"; }
        }
        catch (Exception ex) { LoginStatus.Text = ex.Message; }
        finally { LoginButton.IsEnabled = true; }
    }

    private async Task RefreshRoomsAsync(string? selectId = null)
    {
        var rooms = await _api.GetRoomsAsync();
        _rooms.Clear(); foreach (var room in rooms) _rooms.Add(room);
        if (selectId is not null) RoomList.SelectedItem = _rooms.FirstOrDefault(x => x.Id == selectId);
        else if (_rooms.Count > 0) RoomList.SelectedIndex = 0;
    }

    private async void RoomList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (RoomList.SelectedItem is not Room room) return;
        _room = room; _replyTo = null; ReplyBanner.Visibility = Visibility.Collapsed;
        RoomTitle.Text = $"{room.Icon} {room.DisplayName}"; RoomSubtitle.Text = room.Type switch { "d" => "私信", "p" => "私有频道", "l" => "在线客服", _ => "公开频道" };
        await LoadHistoryAsync(room);
        try { await _api.MarkReadAsync(room.Id); room.Unread = 0; } catch { }
        try { await _realtime.SubscribeRoomAsync(room.Id); } catch { }
        ComposerBox.Focus();
    }

    private async Task LoadHistoryAsync(Room room)
    {
        _loadCts?.Cancel(); _loadCts?.Dispose(); _loadCts = new();
        try
        {
            var messages = await _api.GetHistoryAsync(room, 100, ct: _loadCts.Token);
            if (_room?.Id != room.Id) return;
            _messages.Clear(); foreach (var message in messages) _messages.Add(message);
            ScrollToEnd();
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { ShowError(ex); }
    }

    private async void Send_Click(object sender, RoutedEventArgs e) => await SendAsync();
    private async void ComposerBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && (Keyboard.Modifiers & ModifierKeys.Shift) == 0) { e.Handled = true; await SendAsync(); }
    }

    private async Task SendAsync()
    {
        var text = ComposerBox.Text.Trim(); if (_room is null || text.Length == 0) return;
        SendButton.IsEnabled = false;
        try
        {
            var message = await _api.SendMessageAsync(_room.Id, text, _replyTo?.Id);
            ComposerBox.Clear(); CancelReply(); AddOrUpdateMessage(message); ScrollToEnd();
        }
        catch (Exception ex) { ShowError(ex); }
        finally { SendButton.IsEnabled = true; ComposerBox.Focus(); }
    }

    private void Realtime_MessageReceived(object? sender, ChatMessage message) => Dispatcher.Invoke(() =>
    {
        if (message.RoomId == _room?.Id) { AddOrUpdateMessage(message); ScrollToEnd(); }
        else { var room = _rooms.FirstOrDefault(x => x.Id == message.RoomId); if (room is not null) room.Unread++; }
    });

    private void AddOrUpdateMessage(ChatMessage message)
    {
        var existing = _messages.FirstOrDefault(x => x.Id == message.Id);
        if (existing is null) _messages.Add(message); else { var index = _messages.IndexOf(existing); _messages[index] = message; }
    }

    private async void MessageSearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || _room is null) return; e.Handled = true;
        var term = MessageSearchBox.Text.Trim(); if (term.Length == 0) return;
        try { var result = await _api.SearchMessagesAsync(_room.Id, term); _messages.Clear(); foreach (var m in result) _messages.Add(m); SearchLabel.Text = $"“{term}” 的搜索结果：{result.Count} 条"; SearchBanner.Visibility = Visibility.Visible; }
        catch (Exception ex) { ShowError(ex); }
    }

    private async void ClearSearch_Click(object sender, RoutedEventArgs e) { SearchBanner.Visibility = Visibility.Collapsed; MessageSearchBox.Clear(); if (_room is not null) await LoadHistoryAsync(_room); }
    private void RoomFilterBox_TextChanged(object sender, TextChangedEventArgs e) => _roomView?.Refresh();
    private bool FilterRoom(object item) => item is Room room && (RoomFilterBox.Text.Length == 0 || room.DisplayName.Contains(RoomFilterBox.Text, StringComparison.CurrentCultureIgnoreCase));

    private void ReplyMessage_Click(object sender, RoutedEventArgs e)
    {
        if (MessageList.SelectedItem is not ChatMessage message) return; _replyTo = message;
        ReplyLabel.Text = $"回复 {message.AuthorLabel}：{message.Text.Replace('\n', ' ')}"; ReplyBanner.Visibility = Visibility.Visible; ComposerBox.Focus();
    }
    private void CancelReply_Click(object sender, RoutedEventArgs e) => CancelReply();
    private void CancelReply() { _replyTo = null; ReplyBanner.Visibility = Visibility.Collapsed; }

    private async void EditMessage_Click(object sender, RoutedEventArgs e)
    {
        if (MessageList.SelectedItem is not ChatMessage message || _room is null) return;
        if (message.UserId != _api.Session?.UserId) { ShowError(new Exception("只能编辑自己发送的消息。")); return; }
        var text = InputDialog.Show(this, "编辑消息", "消息内容", message.Text); if (text is null || text.Trim().Length == 0) return;
        try { await _api.UpdateMessageAsync(_room.Id, message.Id, text.Trim()); await LoadHistoryAsync(_room); } catch (Exception ex) { ShowError(ex); }
    }

    private async void DeleteMessage_Click(object sender, RoutedEventArgs e)
    {
        if (MessageList.SelectedItem is not ChatMessage message || _room is null) return;
        if (message.UserId != _api.Session?.UserId) { ShowError(new Exception("只能删除自己发送的消息。")); return; }
        if (MessageBox.Show("确定删除这条消息？", "删除消息", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        try { await _api.DeleteMessageAsync(_room.Id, message.Id); _messages.Remove(message); } catch (Exception ex) { ShowError(ex); }
    }

    private async void ReactMessage_Click(object sender, RoutedEventArgs e)
    {
        if (MessageList.SelectedItem is not ChatMessage message) return;
        try { await _api.ReactAsync(message.Id, ":+1:"); RealtimeStatus.Text = "已添加 👍"; } catch (Exception ex) { ShowError(ex); }
    }

    private async void Upload_Click(object sender, RoutedEventArgs e)
    {
        if (_room is null) return; var dialog = new OpenFileDialog { Title = "选择要上传的文件" }; if (dialog.ShowDialog(this) != true) return;
        try { RealtimeStatus.Text = "正在上传…"; await _api.UploadFileAsync(_room.Id, dialog.FileName); RealtimeStatus.Text = "上传完成"; } catch (Exception ex) { ShowError(ex); }
    }

    private async void NewConversation_Click(object sender, RoutedEventArgs e)
    {
        var choice = NewConversationDialog.Show(this); if (choice is null) return;
        try
        {
            string roomId;
            if (choice.Kind == NewConversationKind.Direct)
            {
                var users = await _api.SearchUsersAsync(choice.Name); var user = users.FirstOrDefault(x => x.Username.Equals(choice.Name.TrimStart('@'), StringComparison.OrdinalIgnoreCase)) ?? users.FirstOrDefault();
                if (user is null) throw new RocketChatException("未找到该用户。");
                roomId = await _api.CreateDirectMessageAsync(user.Username);
            }
            else roomId = await _api.CreateChannelAsync(choice.Name, choice.Kind == NewConversationKind.PrivateChannel);
            await RefreshRoomsAsync(roomId);
        }
        catch (Exception ex) { ShowError(ex); }
    }

    private async void Logout_Click(object sender, RoutedEventArgs e) => await LogoutAsync();
    private async Task LogoutAsync()
    {
        await _realtime.DisconnectAsync(); try { await _api.LogoutAsync(); } catch { }
        _rooms.Clear(); _messages.Clear(); _room = null; ChatView.Visibility = Visibility.Collapsed; LoginView.Visibility = Visibility.Visible; LoginStatus.Text = ""; UsernameBox.Focus();
    }

    private async void MainWindow_Closing(object? sender, CancelEventArgs e) { await _realtime.DisposeAsync(); _api.Dispose(); }
    private void ScrollToEnd() { if (_messages.Count > 0) MessageList.ScrollIntoView(_messages[^1]); }
    private static void ShowError(Exception ex) => MessageBox.Show(ex.Message, "Rocket.Chat", MessageBoxButton.OK, MessageBoxImage.Warning);
}
