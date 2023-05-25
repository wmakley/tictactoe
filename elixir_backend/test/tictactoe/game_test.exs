defmodule Tictactoe.GameTest do
  use ExUnit.Case, async: true

  alias Tictactoe.Game
  alias Tictactoe.Player

  test "new game" do
    game = Game.new("test")
    assert game.id == "test"
  end

  test "json encoding" do
    game = Game.new("test")

    assert Jason.encode!(game) ==
             ~S({"board":[" "," "," "," "," "," "," "," "," "],"chat":[],"players":[],"turn":"X","winner":null})
  end

  test "add player" do
    game = Game.new("test")
    {:ok, player, game} = Game.add_player(game, "Player 1")
    assert player == %Player{id: 1, name: "Player 1", team: "X", wins: 0}
    assert game.players == [%Player{id: 1, name: "Player 1", team: "X", wins: 0}]

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
    game = Game.new("update-test")

    {:ok, player, game} = Game.add_player(game, "Player 1")
    {:ok, game} = Game.update_player_name(game, player.id, "Player 1 Updated")

    assert game.players == [%Player{id: 1, name: "Player 1 Updated", team: "X", wins: 0}]
  end

  test "update player name when player id is invalid" do
    game = Game.new("update-test")

    {:error, msg} = Game.update_player_name(game, 1, "Player 1 Updated")

    assert msg == "Player not found"
  end

  test "remove_player" do
    game = Game.new("browser-msg-test")

    {:ok, player, game} = Game.add_player(game, "Player 1")
    {:ok, game} = Game.remove_player(game, player.id)

    assert game.players == []

    {:error, msg} = Game.remove_player(game, 2)
    assert msg == "Player not found"
  end

  test "take_turn" do
    game = Game.new("take-turn-test")

    {:ok, p1, game} = Game.add_player(game, "Player 1")
    {:error, msg} = Game.take_turn(game, p1.id, 0)
    assert msg == "Not enough players"

    {:ok, p2, game} = Game.add_player(game, "Player 2")
    {:error, msg} = Game.take_turn(game, p2.id, 0)
    assert msg == "Not your turn"

    {:ok, game} = Game.take_turn(game, p1.id, 0)
    assert game.board == ["X", " ", " ", " ", " ", " ", " ", " ", " "]

    {:ok, game} = Game.take_turn(game, p2.id, 1)
    assert game.board == ["X", "O", " ", " ", " ", " ", " ", " ", " "]
  end
end
