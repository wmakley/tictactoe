defmodule Tictactoe.Game do
  @derive {Jason.Encoder, except: [:id]}
  defstruct [
    :id,
    players: [],
    board: [" ", " ", " ", " ", " ", " ", " ", " ", " "],
    turn: "X",
    winner: nil,
    chat: []
  ]

  def new(id) do
    %Tictactoe.Game{id: id}
  end
end
