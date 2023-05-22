defmodule Tictactoe.Player do
  @derive Jason.Encoder
  defstruct [:id, :team, :name, wins: 0]
end
