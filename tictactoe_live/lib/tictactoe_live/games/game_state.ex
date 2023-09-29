defmodule TictactoeLive.Games.GameState do
  @moduledoc """
  Data structure representing the state of a game of Tic-Tac-Toe.
  """

  defstruct players: [],
            board: [" ", " ", " ", " ", " ", " ", " ", " ", " "],
            turn: "X",
            winner: nil,
            chat: [],
            next_chat_id: 1

  alias TictactoeLive.Games.Player
  alias TictactoeLive.Games.ChatMessage

  @spec new() :: %__MODULE__{}
  def new() do
    %__MODULE__{}
  end

  @spec add_player(%__MODULE__{}, String.t()) ::
          {:ok, %Player{}, %__MODULE__{}} | {:error, String.t()}
  def add_player(%__MODULE__{players: players} = game, name) when is_binary(name) do
    if length(players) == 2 do
      {:error, "Game is full"}
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

  defp add_player(%__MODULE__{} = game, name, id, team)
       when is_binary(name) and is_integer(id) and is_binary(team) do
    player = %Player{id: id, name: name, team: team}

    game =
      %{game | players: game.players ++ [player]}
      |> add_chat_message(:system, "#{name} (#{team}) has joined the game")

    {:ok, player, game}
  end

  @spec enough_players?(%__MODULE__{}) :: boolean()
  def enough_players?(%__MODULE__{} = game) do
    length(game.players) == 2
  end

  @doc """
  Return true if the game is in progress (all players have joined, but no winner yet)
  """
  @spec in_game?(%__MODULE__{}) :: boolean()
  def in_game?(%__MODULE__{winner: winner} = game) do
    winner == nil && enough_players?(game)
  end

  def update_player_name(%__MODULE__{} = game, id, name)
      when is_integer(id) and is_binary(name) do
    trimmed = String.trim(name)

    normalized =
      case trimmed do
        "" ->
          "Unnamed Player"

        _ ->
          trimmed
      end

    with {:ok, game} <- update_player(game, id, fn p -> %{p | name: normalized} end) do
      game =
        game
        |> add_chat_message({:player, id}, "Now my name is \"#{normalized}\"!")

      {:ok, game}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_player(%__MODULE__{} = game, id, update_fn) when is_integer(id) do
    case find_player(game, id) do
      {:error, reason} ->
        {:error, reason}

      {:ok, player} ->
        updated_player = update_fn.(player)

        game = %{
          game
          | players:
              Enum.map(game.players, fn p -> if p.id == id, do: updated_player, else: p end)
        }

        {:ok, game}
    end
  end

  def chat_messages_with_player_details(%__MODULE__{chat: chat} = game) do
    Enum.map(chat, fn chat_message ->
      case chat_message.source do
        {:player, id} ->
          {:ok, player} = find_player(game, id)
          %ChatMessage{chat_message | source: {:player, player}}

        :system ->
          chat_message
      end
    end)
  end

  @spec find_player(game :: %__MODULE__{}, id :: integer) ::
          {:ok, %Player{}} | {:error, String.t()}
  def find_player(%__MODULE__{} = game, id) when is_integer(id) do
    case Enum.find(game.players, fn p -> p.id == id end) do
      nil ->
        {:error, "Player not found"}

      player ->
        {:ok, player}
    end
  end

  @spec remove_player(game :: %__MODULE__{}, id :: integer) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def remove_player(%__MODULE__{} = game, id) when is_integer(id) do
    case find_player(game, id) do
      {:error, reason} ->
        {:error, reason}

      {:ok, player} ->
        game =
          %{
            game
            | players: Enum.filter(game.players, fn p -> p.id != id end)
          }
          |> add_chat_message(:system, "#{Player.to_string(player)} has left the game")

        {:ok, game}
    end
  end

  @doc """
  Attempt to add a player chat message to the game,
  with validation and normalization (trimming).
  """
  @spec add_player_chat_message(%__MODULE__{}, integer, String.t()) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def add_player_chat_message(%__MODULE__{} = game, player_id, message)
      when is_integer(player_id) and is_binary(message) do
    with {:ok, _} <- find_player(game, player_id),
         {:ok, trimmed} <- validate_chat_msg(message) do
      {:ok, add_chat_message(game, {:player, player_id}, trimmed)}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec validate_chat_msg(text :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp validate_chat_msg(text) do
    trimmed = String.trim(text)
    length = String.length(trimmed)

    cond do
      length == 0 ->
        {:error, "Empty message"}

      length > 500 ->
        {:error, "Message cannot be longer than 500 characters"}

      true ->
        {:ok, trimmed}
    end
  end

  defp add_chat_message(%__MODULE__{} = game, source, text) do
    chat_message = ChatMessage.new(game.next_chat_id, source, text)

    %{
      game
      | chat: game.chat ++ [chat_message],
        next_chat_id: game.next_chat_id + 1
    }
  end

  @spec take_turn(%__MODULE__{}, integer, integer) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def take_turn(game, player_id, space)
      when is_integer(player_id) and is_integer(space) do
    with true <- game_full?(game),
         {:ok, player} <- find_player(game, player_id),
         true <- my_turn?(game, player),
         true <- valid_move?(game, space) do
      {:ok, take_turn_happy_path(game, player, space)}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp game_full?(%__MODULE__{players: players}) do
    if length(players) == 2 do
      true
    else
      {:error, "Not enough players"}
    end
  end

  defp my_turn?(game, player) do
    cond do
      game.winner != nil ->
        {:error, "Game is over"}

      game.turn != player.team ->
        {:error, "Not your turn"}

      true ->
        true
    end
  end

  defp valid_move?(game, move) when is_integer(move) do
    if move >= 0 and move < 9 do
      case Enum.at(game.board, move) do
        " " ->
          true

        _ ->
          {:error, "Space is already taken"}
      end
    else
      {:error, "Invalid space"}
    end
  end

  @spec take_turn_happy_path(%__MODULE__{}, %Player{}, integer) ::
          %__MODULE__{}
  defp take_turn_happy_path(game, player, space) do
    game = %{
      game
      | board: List.update_at(game.board, space, fn _ -> player.team end),
        turn: if(player.team == "X", do: "O", else: "X")
    }

    game =
      add_chat_message(
        game,
        {:player, player.id},
        "Played #{player.team} at (#{rem(space, 3) + 1}, #{div(space, 3) + 1})."
      )

    case check_for_win(game) do
      nil ->
        if check_for_draw(game) do
          %{game | winner: :draw}
          |> add_chat_message(:system, "It's a draw!")
        else
          game
        end

      {:team, winner} ->
        %{game | winner: winner}
        |> add_chat_message(:system, "#{Player.to_string(player)} wins!")
    end
  end

  @spec check_for_win(game :: %__MODULE__{}) :: {:team, String.t()} | nil
  defp check_for_win(game) do
    winning_combinations = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6]
    ]

    Enum.reduce(winning_combinations, nil, fn [a, b, c], winner ->
      if winner != nil do
        winner
      else
        if Enum.all?([a, b, c], fn i -> Enum.at(game.board, i) == "X" end) do
          {:team, "X"}
        else
          if Enum.all?([a, b, c], fn i -> Enum.at(game.board, i) == "O" end) do
            {:team, "O"}
          else
            nil
          end
        end
      end
    end)
  end

  defp check_for_draw(game) do
    Enum.all?(game.board, fn space -> space != " " end)
  end

  @spec rematch(%__MODULE__{}, integer) :: {:ok, %__MODULE__{}} | {:error, String.t()}
  def rematch(%__MODULE__{} = game, player_id) do
    {:ok,
     game
     |> reset
     |> swap_teams
     |> add_chat_message({:player, player_id}, "Rematch!")}
  end

  defp reset(game) do
    %{
      game
      | board: [" ", " ", " ", " ", " ", " ", " ", " ", " "],
        turn: "X",
        winner: nil
    }
  end

  defp swap_teams(game) do
    %{
      game
      | players:
          Enum.map(game.players, fn player ->
            %Player{player | team: if(player.team == "X", do: "O", else: "X")}
          end)
    }
  end

  @spec to_json(%__MODULE__{}) :: map()
  def to_json(%__MODULE__{} = game) do
    %{
      board: game.board,
      chat: game.chat |> Enum.map(&ChatMessage.to_json/1),
      players: game.players |> Enum.map(&Player.to_json/1),
      turn: game.turn,
      winner:
        case game.winner do
          nil ->
            nil

          :draw ->
            "Draw"

          "X" ->
            %{"Win" => "X"}

          "O" ->
            %{"Win" => "O"}
        end
    }
  end
end

defimpl Jason.Encoder, for: TictactoeLive.Games.GameState do
  def encode(game, opts) do
    Jason.Encode.map(TictactoeLive.Games.GameState.to_json(game), opts)
  end
end
