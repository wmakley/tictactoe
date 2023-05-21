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

  alias Tictactoe.Game
  alias Tictactoe.Player

  def new(id) do
    %Game{id: id}
  end

  def add_player(%Game{players: players} = game, name) do
    if length(players) == 2 do
      {:error, "Game is full", game}
    else
      case List.last(players) do
        nil ->
          add_player(game, name, 1, "X")

        %Player{id: id, team: "X"} ->
          add_player(game, name, id + 1, "O")

        %Player{id: id, team: "O"} ->
          add_player(game, name, id + 1, "X")
      end
    end
  end

  defp add_player(game, name, id, team) do
    player = %Player{id: id, name: name, team: team}
    game = %{game | players: game.players ++ [player]}
    {:ok, player, game}
  end
end
