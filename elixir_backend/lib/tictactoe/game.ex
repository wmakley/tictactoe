defmodule Tictactoe.Game do
  defstruct [
    :id,
    players: [],
    board: [" ", " ", " ", " ", " ", " ", " ", " ", " "],
    turn: "X",
    winner: nil,
    chat: []
  ]

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
    case find_player(game, id) do
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

  defp find_player(%__MODULE__{} = game, id) when is_integer(id) do
    Enum.find(game.players, fn p -> p.id == id end)
  end

  def remove_player(%__MODULE__{} = game, id) when is_integer(id) do
    case find_player(game, id) do
      nil ->
        {:error, "Player not found"}

      _player ->
        game = %{
          game
          | players: Enum.filter(game.players, fn p -> p.id != id end)
        }

        {:ok, game}
    end
  end

  def take_turn(%__MODULE__{players: players} = game, id, space)
      when is_integer(id) and is_integer(space) do
    case length(players) do
      2 ->
        case find_player(game, id) do
          nil ->
            {:error, "Player not found"}

          %Player{id: ^id, team: team} ->
            if game.turn != team do
              {:error, "Not your turn"}
            else
              take_turn_happy_path(game, team, space)
            end
        end

      _ ->
        {:error, "Not enough players"}
    end
  end

  defp take_turn_happy_path(game, team, space) do
    game = %{
      game
      | board: List.update_at(game.board, space, fn _ -> team end),
        turn: if(team == "X", do: "O", else: "X")
    }

    {:ok, game}
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
