using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.IO;
using System.Text;
using System.Text.Json;

namespace RocketChat.Client;

public sealed class RocketChatApi : IDisposable
{
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(30) };
    private readonly JsonSerializerOptions _json = new() { PropertyNameCaseInsensitive = true };
    public Uri? ServerUri { get; private set; }
    public Session? Session { get; private set; }

    public async Task<(string Version, string Name)> GetServerInfoAsync(string server, CancellationToken ct = default)
    {
        ConfigureServer(server);
        using var doc = await SendAsync(HttpMethod.Get, "api/info", null, false, ct);
        var info = doc.RootElement.TryGetProperty("info", out var i) ? i : doc.RootElement;
        return (GetString(info, "version"), GetString(info, "name", ServerUri!.Host));
    }

    public async Task<Session> LoginAsync(string server, string username, string password, CancellationToken ct = default)
    {
        ConfigureServer(server);
        using var doc = await SendAsync(HttpMethod.Post, "api/v1/login", new { user = username, password }, false, ct);
        var data = doc.RootElement.GetProperty("data");
        var me = data.GetProperty("me");
        Session = new(GetString(data, "userId"), GetString(data, "authToken"), GetString(me, "username", username), GetString(me, "name", username));
        return Session;
    }

    public async Task LogoutAsync(CancellationToken ct = default)
    {
        if (Session is null) return;
        try { using var _ = await SendAsync(HttpMethod.Post, "api/v1/logout", new { }, true, ct); }
        finally { Session = null; }
    }

    public async Task<IReadOnlyList<Room>> GetRoomsAsync(CancellationToken ct = default)
    {
        using var doc = await SendAsync(HttpMethod.Get, "api/v1/subscriptions.get", null, true, ct);
        var root = doc.RootElement;
        var array = root.TryGetProperty("update", out var update) ? update : root.TryGetProperty("subscriptions", out var subscriptions) ? subscriptions : default;
        if (array.ValueKind != JsonValueKind.Array) return [];
        return array.EnumerateArray().Where(x => GetBool(x, "open", true)).Select(x => new Room
        {
            Id = GetString(x, "rid"), Name = GetString(x, "name"), DisplayName = GetString(x, "fname", GetString(x, "name")),
            Type = GetString(x, "t", "c"), Unread = GetInt(x, "unread"), IsFavorite = GetBool(x, "f"), IsOpen = GetBool(x, "open", true),
            LastMessageAt = GetDate(x, "ls")
        }).Where(x => x.Id.Length > 0).OrderByDescending(x => x.IsFavorite).ThenByDescending(x => x.LastMessageAt).ToList();
    }

    public async Task<IReadOnlyList<ChatMessage>> GetHistoryAsync(Room room, int count = 50, DateTimeOffset? latest = null, CancellationToken ct = default)
    {
        var endpoint = room.Type switch { "d" => "im.history", "p" => "groups.history", _ => "channels.history" };
        var query = $"api/v1/{endpoint}?roomId={E(room.Id)}&count={Math.Clamp(count, 1, 100)}" + (latest is null ? "" : $"&latest={E(latest.Value.UtcDateTime.ToString("O"))}");
        using var doc = await SendAsync(HttpMethod.Get, query, null, true, ct);
        if (!doc.RootElement.TryGetProperty("messages", out var messages)) return [];
        return messages.EnumerateArray().Select(ParseMessage).OrderBy(x => x.Timestamp).ToList();
    }

    public async Task<ChatMessage> SendMessageAsync(string roomId, string text, string? threadId = null, CancellationToken ct = default)
    {
        var message = threadId is null ? new Dictionary<string, object?> { ["rid"] = roomId, ["msg"] = text }
            : new Dictionary<string, object?> { ["rid"] = roomId, ["msg"] = text, ["tmid"] = threadId };
        using var doc = await SendAsync(HttpMethod.Post, "api/v1/chat.sendMessage", new { message }, true, ct);
        return ParseMessage(doc.RootElement.GetProperty("message"));
    }

    public async Task UpdateMessageAsync(string roomId, string messageId, string text, CancellationToken ct = default)
    { using var _ = await SendAsync(HttpMethod.Post, "api/v1/chat.update", new { roomId, msgId = messageId, text }, true, ct); }

    public async Task DeleteMessageAsync(string roomId, string messageId, CancellationToken ct = default)
    { using var _ = await SendAsync(HttpMethod.Post, "api/v1/chat.delete", new { roomId, msgId = messageId, asUser = true }, true, ct); }

    public async Task ReactAsync(string messageId, string emoji, bool shouldReact = true, CancellationToken ct = default)
    { using var _ = await SendAsync(HttpMethod.Post, "api/v1/chat.react", new { messageId, emoji, shouldReact }, true, ct); }

    public async Task MarkReadAsync(string roomId, CancellationToken ct = default)
    { using var _ = await SendAsync(HttpMethod.Post, "api/v1/subscriptions.read", new { rid = roomId }, true, ct); }

    public async Task<IReadOnlyList<ChatMessage>> SearchMessagesAsync(string roomId, string text, CancellationToken ct = default)
    {
        using var doc = await SendAsync(HttpMethod.Get, $"api/v1/chat.search?roomId={E(roomId)}&searchText={E(text)}&count=100", null, true, ct);
        if (!doc.RootElement.TryGetProperty("messages", out var messages)) return [];
        return messages.EnumerateArray().Select(ParseMessage).OrderBy(x => x.Timestamp).ToList();
    }

    public async Task<IReadOnlyList<UserSearchResult>> SearchUsersAsync(string term, CancellationToken ct = default)
    {
        var selector = JsonSerializer.Serialize(new { term });
        using var doc = await SendAsync(HttpMethod.Get, $"api/v1/users.autocomplete?selector={E(selector)}", null, true, ct);
        var items = doc.RootElement.TryGetProperty("items", out var i) ? i : doc.RootElement.TryGetProperty("users", out var u) ? u : default;
        if (items.ValueKind != JsonValueKind.Array) return [];
        return items.EnumerateArray().Select(x => new UserSearchResult(GetString(x, "_id"), GetString(x, "username"), GetString(x, "name"), GetString(x, "status"))).ToList();
    }

    public async Task<string> CreateDirectMessageAsync(string username, CancellationToken ct = default)
    {
        using var doc = await SendAsync(HttpMethod.Post, "api/v1/im.create", new { username }, true, ct);
        return GetString(doc.RootElement.GetProperty("room"), "rid");
    }

    public async Task<string> CreateChannelAsync(string name, bool isPrivate, CancellationToken ct = default)
    {
        var endpoint = isPrivate ? "groups.create" : "channels.create";
        using var doc = await SendAsync(HttpMethod.Post, $"api/v1/{endpoint}", new { name, members = Array.Empty<string>() }, true, ct);
        var key = isPrivate ? "group" : "channel";
        return GetString(doc.RootElement.GetProperty(key), "_id");
    }

    public async Task UploadFileAsync(string roomId, string filePath, string? description = null, CancellationToken ct = default)
    {
        EnsureAuthenticated();
        await using var stream = File.OpenRead(filePath);
        using var form = new MultipartFormDataContent();
        var file = new StreamContent(stream);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        form.Add(file, "file", Path.GetFileName(filePath));
        if (!string.IsNullOrWhiteSpace(description)) form.Add(new StringContent(description), "description");
        using var request = NewRequest(HttpMethod.Post, $"api/v1/rooms.upload/{E(roomId)}", true);
        request.Content = form;
        using var response = await _http.SendAsync(request, ct);
        await EnsureSuccessAsync(response, ct);
    }

    private async Task<JsonDocument> SendAsync(HttpMethod method, string path, object? body, bool auth, CancellationToken ct)
    {
        using var request = NewRequest(method, path, auth);
        if (body is not null) request.Content = JsonContent.Create(body, options: _json);
        using var response = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
        return await EnsureSuccessAsync(response, ct);
    }

    private HttpRequestMessage NewRequest(HttpMethod method, string path, bool auth)
    {
        if (ServerUri is null) throw new InvalidOperationException("尚未配置服务器。");
        var request = new HttpRequestMessage(method, new Uri(ServerUri, path));
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.UserAgent.ParseAdd("RocketChat-CSharp/1.0");
        if (auth)
        {
            EnsureAuthenticated();
            request.Headers.Add("X-User-Id", Session!.UserId);
            request.Headers.Add("X-Auth-Token", Session.AuthToken);
        }
        return request;
    }

    private static async Task<JsonDocument> EnsureSuccessAsync(HttpResponseMessage response, CancellationToken ct)
    {
        var content = await response.Content.ReadAsStringAsync(ct);
        if (response.IsSuccessStatusCode)
            return JsonDocument.Parse(string.IsNullOrWhiteSpace(content) ? "{}" : content);
        string message = $"服务器返回 {(int)response.StatusCode} {response.ReasonPhrase}"; string? type = null;
        try { using var error = JsonDocument.Parse(content); message = GetString(error.RootElement, "message", GetString(error.RootElement, "error", message)); type = GetString(error.RootElement, "errorType"); } catch { }
        if (response.StatusCode == HttpStatusCode.Unauthorized) message = "登录失败或会话已过期，请检查账号、密码和服务器地址。";
        throw new RocketChatException(message, type);
    }

    private void ConfigureServer(string server)
    {
        if (!Uri.TryCreate(server.Trim(), UriKind.Absolute, out var uri) || (uri.Scheme != "http" && uri.Scheme != "https"))
            throw new RocketChatException("请输入有效的 http:// 或 https:// 服务器地址。");
        ServerUri = new Uri(uri.GetLeftPart(UriPartial.Authority) + uri.AbsolutePath.TrimEnd('/') + "/");
    }

    private void EnsureAuthenticated() { if (Session is null) throw new RocketChatException("请先登录。"); }
    private static string E(string value) => Uri.EscapeDataString(value);
    internal static string GetString(JsonElement e, string name, string fallback = "") => e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? fallback : fallback;
    private static int GetInt(JsonElement e, string name) => e.TryGetProperty(name, out var v) && v.TryGetInt32(out var n) ? n : 0;
    private static bool GetBool(JsonElement e, string name, bool fallback = false) => e.TryGetProperty(name, out var v) && (v.ValueKind == JsonValueKind.True || v.ValueKind == JsonValueKind.False) ? v.GetBoolean() : fallback;
    private static DateTimeOffset? GetDate(JsonElement e, string name) => e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && DateTimeOffset.TryParse(v.GetString(), out var d) ? d : null;
    internal static ChatMessage ParseMessage(JsonElement x)
    {
        var u = x.TryGetProperty("u", out var user) ? user : default;
        return new ChatMessage { Id = GetString(x, "_id"), RoomId = GetString(x, "rid"), UserId = GetString(u, "_id"), Username = GetString(u, "username"), DisplayName = GetString(u, "name"), Text = GetString(x, "msg"), Timestamp = GetDate(x, "ts") ?? DateTimeOffset.Now, Edited = x.TryGetProperty("editedAt", out _), IsSystem = !string.IsNullOrEmpty(GetString(x, "t")), ThreadId = GetString(x, "tmid"), ReplyCount = GetInt(x, "tcount") };
    }
    public void Dispose() => _http.Dispose();
}
