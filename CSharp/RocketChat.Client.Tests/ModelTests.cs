using System.Text.Json;
using Xunit;

namespace RocketChat.Client.Tests;

public sealed class ModelTests
{
    [Fact]
    public void ParseMessage_MapsRocketChatPayload()
    {
        using var json = JsonDocument.Parse("""
        { "_id":"m1", "rid":"GENERAL", "msg":"hello", "ts":"2026-08-30T08:00:00Z",
          "editedAt":"2026-08-30T08:01:00Z", "u":{"_id":"u1","username":"coder","name":"Coder"}, "tcount":2 }
        """);
        var message = RocketChatApi.ParseMessage(json.RootElement);
        Assert.Equal("m1", message.Id);
        Assert.Equal("GENERAL", message.RoomId);
        Assert.Equal("Coder", message.AuthorLabel);
        Assert.Equal("C", message.AuthorInitial);
        Assert.Equal("hello", message.Text);
        Assert.True(message.Edited);
        Assert.Equal(2, message.ReplyCount);
    }

    [Theory]
    [InlineData("c", "#")]
    [InlineData("p", "◆")]
    [InlineData("d", "●")]
    public void Room_UsesExpectedIcon(string type, string icon) => Assert.Equal(icon, new Room { Type = type }.Icon);

    [Fact]
    public void Room_UnreadLabel_IsCapped()
    {
        var room = new Room { Unread = 120 };
        Assert.Equal("99+", room.UnreadLabel);
        room.Unread = 0;
        Assert.Equal("", room.UnreadLabel);
    }
}
