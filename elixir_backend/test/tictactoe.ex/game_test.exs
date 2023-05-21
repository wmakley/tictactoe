defmodule Tictactoe.GameTest do
  use ExUnit.Case, async: true

  test "new game" do
    game = Tictactoe.Game.new("123")
    assert game.id == "123"
  end

  test "json encoding" do
    game = Tictactoe.Game.new("123")

    assert Jason.encode!(game) ==
             ~S({"board":[" "," "," "," "," "," "," "," "," "],"chat":[],"players":[],"turn":"X","winner":null})
  end
end
