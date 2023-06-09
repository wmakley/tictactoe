defmodule Tictactoe.GameTest do
  use ExUnit.Case, async: true

  alias Tictactoe.Game
  alias Tictactoe.Player
  alias Tictactoe.ChatMessage

  test "json encoding" do
    game = Game.new()

    assert Jason.encode!(game) ==
             ~S({"board":[" "," "," "," "," "," "," "," "," "],"chat":[],"players":[],"turn":"X","winner":null})
  end

  test "add player" do
    game = Game.new()
    {:ok, player, game} = Game.add_player(game, "Player 1")
    assert player == %Player{id: 1, name: "Player 1", team: "X", wins: 0}
    assert game.players == [%Player{id: 1, name: "Player 1", team: "X", wins: 0}]

    assert game.chat == [
             %ChatMessage{
               id: 1,
               source: :system,
               text: "Player 1 (X) has joined the game"
             }
           ]

    {:ok, player, game} = Game.add_player(game, "Player 2")
    assert player == %Player{id: 2, name: "Player 2", team: "O", wins: 0}

    assert game.players == [
             %Player{id: 1, name: "Player 1", team: "X", wins: 0},
             %Player{id: 2, name: "Player 2", team: "O", wins: 0}
           ]

    {:error, msg, _game} = Game.add_player(game, "Player 3")
    assert msg == "Game is full"
  end

  test "update_player_name" do
    game = Game.new()

    {:ok, player, game} = Game.add_player(game, "Player 1")
    {:ok, game} = Game.update_player_name(game, player.id, "Player 1 Updated")

    assert game.players == [%Player{id: 1, name: "Player 1 Updated", team: "X", wins: 0}]

    assert List.last(game.chat) == %ChatMessage{
             id: 2,
             source: {:player, 1},
             text: "Now my name is \"Player 1 Updated\"!"
           }
  end

  test "update player name when player id is invalid" do
    game = Game.new()

    {:error, msg} = Game.update_player_name(game, 1, "Player 1 Updated")

    assert msg == "Player not found"
  end

  test "remove_player" do
    game = Game.new()

    {:ok, player, game} = Game.add_player(game, "Player 1")
    {:ok, game} = Game.remove_player(game, player.id)

    assert game.players == []

    {:error, msg} = Game.remove_player(game, 2)
    assert msg == "Player not found"
  end

  test "take_turn" do
    game = Game.new()

    {:ok, p1, game} = Game.add_player(game, "Player 1")
    {:error, msg} = Game.take_turn(game, p1.id, 0)
    assert msg == "Not enough players"

    {:ok, p2, game} = Game.add_player(game, "Player 2")
    {:error, msg} = Game.take_turn(game, p2.id, 0)
    assert msg == "Not your turn"

    {:ok, game} = Game.take_turn(game, p1.id, 0)
    assert game.board == ["X", " ", " ", " ", " ", " ", " ", " ", " "]

    assert List.last(game.chat) == %ChatMessage{
             id: 3,
             source: {:player, p1.id},
             text: "Played X at (1, 1)."
           }

    {:ok, game} = Game.take_turn(game, p2.id, 1)
    assert game.board == ["X", "O", " ", " ", " ", " ", " ", " ", " "]
    # TODO: chat
  end

  test "add chat message" do
    game = Game.new()

    {:ok, p1, game} = Game.add_player(game, "Player 1")
    {:ok, p2, game} = Game.add_player(game, "Player 2")

    assert game.chat == [
             %ChatMessage{
               id: 1,
               source: :system,
               text: "Player 1 (X) has joined the game"
             },
             %ChatMessage{
               id: 2,
               source: :system,
               text: "Player 2 (O) has joined the game"
             }
           ]

    {:error, reason} = Game.add_player_chat_message(game, p1.id, "")
    assert reason == "Empty message"

    {:error, reason} = Game.add_player_chat_message(game, p1.id, "  ")
    assert reason == "Empty message"

    {:error, reason} = Game.add_player_chat_message(game, 999, "valid message")
    assert reason == "Player not found"

    {:error, reason} = Game.add_player_chat_message(game, p2.id, String.duplicate("a", 501))
    assert reason == "Message cannot be longer than 500 characters"

    {:ok, game} = Game.add_player_chat_message(game, p1.id, "valid message")

    assert List.last(game.chat) ==
             %ChatMessage{id: 3, source: {:player, p1.id}, text: "valid message"}

    {:ok, game} = Game.add_player_chat_message(game, p2.id, "valid message 2")

    assert Enum.slice(game.chat, -2..-1) == [
             %ChatMessage{id: 3, source: {:player, p1.id}, text: "valid message"},
             %ChatMessage{id: 4, source: {:player, p2.id}, text: "valid message 2"}
           ]
  end

  test "rematch" do
    game = Game.new()
    {:ok, p1, game} = Game.add_player(game, "Player 1")
    assert p1.team == "X"
    {:ok, p2, game} = Game.add_player(game, "Player 2")
    assert p2.team == "O"

    {:ok, game} = Game.take_turn(game, p1.id, 0)
    {:ok, game} = Game.take_turn(game, p2.id, 1)
    {:ok, game} = Game.take_turn(game, p1.id, 2)
    {:ok, game} = Game.take_turn(game, p2.id, 3)
    {:ok, game} = Game.take_turn(game, p1.id, 4)

    {:ok, game} = Game.rematch(game, p1.id)
    p1 = Enum.find(game.players, fn p -> p.id == p1.id end)
    p2 = Enum.find(game.players, fn p -> p.id == p2.id end)
    assert p1.team == "O"
    assert p2.team == "X"

    assert game.board == [" ", " ", " ", " ", " ", " ", " ", " ", " "]
    assert game.turn == "X"
    assert game.winner == nil

    assert List.last(game.chat) == %ChatMessage{
             id: 8,
             source: {:player, p1.id},
             text: "Rematch!"
           }
  end
end
