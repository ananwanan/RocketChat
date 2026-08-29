using System.Net.WebSockets;
using System.IO;
using System.Text;
using System.Text.Json;

namespace RocketChat.Client;

public sealed class RealtimeClient : IAsyncDisposable
{
    private ClientWebSocket? _socket;
    private CancellationTokenSource? _cts;
    private Task? _receiveTask;
    private readonly Dictionary<string, string> _subscriptions = [];
    public event EventHandler<ChatMessage>? MessageReceived;
    public event EventHandler<string>? ConnectionChanged;

    public async Task ConnectAsync(Uri serverUri, Session session, CancellationToken ct = default)
    {
        await DisconnectAsync();
        _socket = new ClientWebSocket();
        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var builder = new UriBuilder(serverUri) { Scheme = serverUri.Scheme == "https" ? "wss" : "ws", Port = serverUri.IsDefaultPort ? -1 : serverUri.Port, Path = serverUri.AbsolutePath.TrimEnd('/') + "/websocket" };
        await _socket.ConnectAsync(builder.Uri, ct);
        await SendAsync(new { msg = "connect", version = "1", support = new[] { "1" } }, ct);
        await SendAsync(new { msg = "method", method = "login", id = "login", @params = new[] { new { resume = session.AuthToken } } }, ct);
        _receiveTask = ReceiveLoopAsync(_cts.Token);
        ConnectionChanged?.Invoke(this, "实时连接已建立");
    }

    public async Task SubscribeRoomAsync(string roomId, CancellationToken ct = default)
    {
        if (_socket?.State != WebSocketState.Open) return;
        if (_subscriptions.Remove(roomId, out var oldId)) await SendAsync(new { msg = "unsub", id = oldId }, ct);
        var id = Guid.NewGuid().ToString("N");
        _subscriptions[roomId] = id;
        await SendAsync(new { msg = "sub", id, name = "stream-room-messages", @params = new object[] { roomId, false } }, ct);
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        var buffer = new byte[64 * 1024];
        try
        {
            while (_socket?.State == WebSocketState.Open && !ct.IsCancellationRequested)
            {
                using var data = new MemoryStream();
                WebSocketReceiveResult result;
                do { result = await _socket.ReceiveAsync(buffer, ct); if (result.MessageType == WebSocketMessageType.Close) return; data.Write(buffer, 0, result.Count); } while (!result.EndOfMessage);
                using var doc = JsonDocument.Parse(data.ToArray());
                var root = doc.RootElement;
                var type = RocketChatApi.GetString(root, "msg");
                if (type == "ping") { await SendAsync(new { msg = "pong" }, ct); continue; }
                if (type != "changed" || !root.TryGetProperty("fields", out var fields) || RocketChatApi.GetString(fields, "eventName").Length == 0 || !fields.TryGetProperty("args", out var args) || args.ValueKind != JsonValueKind.Array) continue;
                foreach (var item in args.EnumerateArray())
                {
                    var message = item.TryGetProperty("_id", out _) ? item : item.TryGetProperty("message", out var nested) ? nested : default;
                    if (message.ValueKind == JsonValueKind.Object) MessageReceived?.Invoke(this, RocketChatApi.ParseMessage(message));
                }
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { ConnectionChanged?.Invoke(this, $"实时连接中断：{ex.Message}"); }
    }

    private async Task SendAsync(object payload, CancellationToken ct)
    {
        if (_socket?.State != WebSocketState.Open) return;
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload));
        await _socket.SendAsync(bytes, WebSocketMessageType.Text, true, ct);
    }

    public async Task DisconnectAsync()
    {
        if (_cts is not null) await _cts.CancelAsync();
        if (_socket?.State == WebSocketState.Open)
            try { await _socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "logout", CancellationToken.None); } catch { }
        if (_receiveTask is not null) try { await _receiveTask; } catch { }
        _socket?.Dispose(); _socket = null; _receiveTask = null; _subscriptions.Clear();
        _cts?.Dispose(); _cts = null;
    }
    public async ValueTask DisposeAsync() => await DisconnectAsync();
}
