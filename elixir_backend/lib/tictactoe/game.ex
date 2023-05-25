defmodule Tictactoe.Game do
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
  alias Tictactoe.ChatMessage

  def new(id) do
    %__MODULE__{id: id}
  end

  def add_player(%__MODULE__{players: players} = game, name) do
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

  defp add_player(%__MODULE__{} = game, name, id, team) do
    player = %Player{id: id, name: name, team: team}
    game = %{game | players: game.players ++ [player]}
    {:ok, player, game}
  end

  def update_player_name(%__MODULE__{} = game, id, name) when is_integer(id) do
    update_player(game, id, fn p -> %{p | name: name} end)
  end

  defp update_player(%__MODULE__{} = game, id, update_fn) when is_integer(id) do
    case Enum.find(game.players, fn p -> p.id == id end) do
      nil ->
        {:error, "Player not found"}

      player ->
        updated_player = update_fn.(player)

        game = %{
          game
          | players:
              Enum.map(game.players, fn p -> if p.id == id, do: updated_player, else: p end)
        }

        {:ok, game}
    end
  end

  def json_representation(%__MODULE__{} = game) do
    %{
      board: game.board,
      chat: game.chat |> Enum.map(&ChatMessage.json_representation/1),
      players: game.players,
      turn: game.turn,
      winner: game.winner
    }
  end
end

defimpl Jason.Encoder, for: Tictactoe.Game do
  def encode(game, opts) do
    Jason.Encode.map(Tictactoe.Game.json_representation(game), opts)
  end
end
