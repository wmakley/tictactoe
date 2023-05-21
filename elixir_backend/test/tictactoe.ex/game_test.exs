defmodule Tictactoe.GameTest do
  use ExUnit.Case, async: true

  test "new game" do
    game = Tictactoe.Game.new("test")
    assert game.id == "test"
  end

  test "json encoding" do
    game = Tictactoe.Game.new("test")

    assert Jason.encode!(game) ==
             ~S({"board":[" "," "," "," "," "," "," "," "," "],"chat":[],"players":[],"turn":"X","winner":null})
  end

  test "add player" do
    game = Tictactoe.Game.new("test")
    {:ok, player, game} = Tictactoe.Game.add_player(game, "Player 1")
    assert player == %Tictactoe.Player{id: 1, name: "Player 1", team: "X", wins: 0}
    assert game.players == [%Tictactoe.Player{id: 1, name: "Player 1", team: "X", wins: 0}]

    {:ok, player, game} = Tictactoe.Game.add_player(game, "Player 2")
    assert player == %Tictactoe.Player{id: 2, name: "Player 2", team: "O", wins: 0}

    assert game.players == [
             %Tictactoe.Player{id: 1, name: "Player 1", team: "X", wins: 0},
             %Tictactoe.Player{id: 2, name: "Player 2", team: "O", wins: 0}
           ]

    {:error, msg, _game} = Tictactoe.Game.add_player(game, "Player 3")
    assert msg == "Game is full"
  end
end
