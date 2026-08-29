using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace RocketChat.Client;

public sealed record Session(string UserId, string AuthToken, string Username, string DisplayName);

public sealed class Room : INotifyPropertyChanged
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public string Type { get; init; } = "c";
    public bool IsFavorite { get; init; }
    public bool IsOpen { get; init; } = true;
    public DateTimeOffset? LastMessageAt { get; init; }
    private int _unread;
    public int Unread { get => _unread; set { _unread = value; OnPropertyChanged(); OnPropertyChanged(nameof(UnreadLabel)); } }
    public string UnreadLabel => Unread > 99 ? "99+" : Unread > 0 ? Unread.ToString() : "";
    public string Icon => Type switch { "d" => "●", "p" => "◆", "l" => "☏", _ => "#" };
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
}

public sealed class ChatMessage
{
    public string Id { get; init; } = "";
    public string RoomId { get; init; } = "";
    public string UserId { get; init; } = "";
    public string Username { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public string Text { get; set; } = "";
    public DateTimeOffset Timestamp { get; init; }
    public bool Edited { get; init; }
    public bool IsSystem { get; init; }
    public string? ThreadId { get; init; }
    public int ReplyCount { get; init; }
    public string TimeLabel => Timestamp.LocalDateTime.ToString("MM-dd HH:mm");
    public string AuthorLabel => string.IsNullOrWhiteSpace(DisplayName) ? Username : DisplayName;
    public string AuthorInitial => string.IsNullOrWhiteSpace(AuthorLabel) ? "?" : AuthorLabel[..1].ToUpperInvariant();
    public string EditedLabel => Edited ? "（已编辑）" : "";
}

public sealed record UserSearchResult(string Id, string Username, string Name, string Status)
{
    public string Label => string.IsNullOrWhiteSpace(Name) ? $"@{Username}" : $"{Name}  @{Username}";
}

public sealed class RocketChatException(string message, string? errorType = null) : Exception(message)
{
    public string? ErrorType { get; } = errorType;
}
