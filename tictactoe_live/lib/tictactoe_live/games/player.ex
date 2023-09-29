defmodule TictactoeLive.Games.Player do
  @derive Jason.Encoder
  defstruct [:id, :team, :name, wins: 0]

  def new(id, team, name) do
    %__MODULE__{id: id, team: team, name: name}
  end

  def new() do
    %__MODULE__{id: 0, team: "X", name: ""}
  end

  def to_string(%__MODULE__{team: team, name: name}) do
    "#{name} (#{team})"
  end

  @spec to_json(__MODULE__) :: map
  def to_json(player) do
    Map.from_struct(player)
  end
end
