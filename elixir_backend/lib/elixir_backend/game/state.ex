defmodule ElixirBackend.Game.State do
  defstruct turn: "X", winner: nil, players: [], board: {}, chat: []
end
