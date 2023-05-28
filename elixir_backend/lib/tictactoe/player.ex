defmodule Tictactoe.Player do
  @derive Jason.Encoder
  defstruct [:id, :team, :name, wins: 0]

  def to_string(%__MODULE__{team: team, name: name}) do
    "#{name} (#{team})"
  end

  @spec to_json(__MODULE__) :: map
  def to_json(player) do
    Map.from_struct(player)
  end
end
