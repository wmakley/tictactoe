package main

import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestGame_AddPlayer(t *testing.T) {
	game, err := NewGame("test")
	require.NoError(t, err)

	game.Lock()
	defer game.Unlock()

	player, err := game.AddPlayer("test")
	require.NoError(t, err)
	require.NotNil(t, player)

	require.Equal(t, "test", player.Name)
	require.Equal(t, PlayerId(0), player.Id)
	require.Equal(t, 1, len(game.State().Players))
	require.Equal(t, TeamX, game.State().Players[0].Team)
	require.Equal(t, TeamX, player.Team)

	require.Equal(t, 1, len(game.State().Chat))
	chatMessage := game.State().Chat[len(game.State().Chat)-1]
	require.NotNil(t, chatMessage)
	require.Equal(t, "test (X) has joined the game!", chatMessage.Text)
	require.Equal(t, SourceTypeSystem, chatMessage.Source.SourceType)

	player2, err := game.AddPlayer("test2")
	require.NoError(t, err)
	require.NotNil(t, player2)

	require.Equal(t, "test2", player2.Name)
	require.Equal(t, PlayerId(1), player2.Id)
	require.Equal(t, 2, len(game.State().Players))
	require.Equal(t, TeamO, game.State().Players[1].Team)
	require.Equal(t, TeamO, player2.Team)

	require.Equal(t, 2, len(game.State().Chat))
	chatMessage = game.State().Chat[len(game.State().Chat)-1]
	require.NotNil(t, chatMessage)
	require.Equal(t, "test2 (O) has joined the game!", chatMessage.Text)
	require.Equal(t, SourceTypeSystem, chatMessage.Source.SourceType)

	_, err = game.AddPlayer("test3")
	require.NotNil(t, err)
	require.Equal(t, "game is full", err.Error())
}

func TestGame_RemovePlayer(t *testing.T) {
	game, err := NewGame("test")
	require.NoError(t, err)

	game.Lock()
	defer game.Unlock()

	player, err := game.AddPlayer("test")
	require.NoError(t, err)

	player2, err := game.AddPlayer("test2")
	require.NoError(t, err)
	require.Equal(t, 2, len(game.State().Chat))

	err = game.RemovePlayer(player.Id)
	require.NoError(t, err)
	require.Equal(t, 1, len(game.State().Players))

	require.Equal(t, 3, len(game.State().Chat))
	chatMessage := game.State().Chat[len(game.State().Chat)-1]
	require.NotNil(t, chatMessage)
	require.Equal(t, "test (X) has left the game!", chatMessage.Text)
	require.Equal(t, SourceTypeSystem, chatMessage.Source.SourceType)

	err = game.RemovePlayer(player.Id)
	require.NotNil(t, err)
	require.Equal(t, "player not found", err.Error())

	err = game.RemovePlayer(player2.Id)
	require.NoError(t, err)
	require.Equal(t, 0, len(game.State().Players))

	require.Equal(t, 4, len(game.State().Chat))
	chatMessage = game.State().Chat[len(game.State().Chat)-1]
	require.NotNil(t, chatMessage)
	require.Equal(t, "test2 (O) has left the game!", chatMessage.Text)
	require.Equal(t, SourceTypeSystem, chatMessage.Source.SourceType)
}

func TestGame_BrowserMsg_UnmarshalJSON_Rematch(t *testing.T) {
	var msg FromBrowser
	err := msg.UnmarshalJSON([]byte(`"Rematch"`))
	require.NoError(t, err)
	require.Equal(t, FromBrowser{MsgType: MsgTypeRematch}, msg)
}

func TestGame_BrowserMsg_UnmarshalJSON_ChatMsg(t *testing.T) {
	var msg FromBrowser
	err := msg.UnmarshalJSON([]byte(`{"ChatMsg":{"text":"asdf"}}`))
	require.NoError(t, err)
	require.Equal(t, FromBrowser{MsgType: MsgTypeChat, Text: "asdf"}, msg)
}

func TestGame_BrowserMsg_UnmarshalJSON_ChangeName(t *testing.T) {
	var msg FromBrowser
	err := msg.UnmarshalJSON([]byte(`{"ChangeName":{"new_name":"test"}}`))
	require.NoError(t, err)
	require.Equal(t, FromBrowser{MsgType: MsgTypeChangeName, Text: "test"}, msg)
}

func TestGame_BrowserMsg_UnmarshalJSON_Move(t *testing.T) {
	var msg FromBrowser
	err := msg.UnmarshalJSON([]byte(`{"Move":{"space":1}}`))
	require.NoError(t, err)
	require.Equal(t, FromBrowser{MsgType: MsgTypeMove, Space: 1}, msg)
}
