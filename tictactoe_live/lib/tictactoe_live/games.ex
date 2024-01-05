defmodule TictactoeLive.Games do
  @moduledoc """
  The Games context.
  """

  alias TictactoeLive.Games.GameServer
  alias TictactoeLive.Games.GameRegistry
  alias TictactoeLive.Games.GameSupervisor

  @type join_token() :: String.t()

  @spec lookup_or_start_game(join_token()) :: {:ok, join_token(), pid} | {:error, String.t()}
  def lookup_or_start_game(id) when is_binary(id) do
    normalized_id = trimmed_or_random_id(id)

    with {:ok, id} <- validate_id(normalized_id) do
      case Registry.lookup(GameRegistry, id) do
        [{game_pid, nil}] ->
          if Process.alive?(game_pid) do
            {:ok, id, game_pid}
          else
            {:error, "game is not running"}
          end

        [] ->
          case DynamicSupervisor.start_child(
                 GameSupervisor,
                 {GameServer, id: id, name: game_name(id)}
               ) do
            {:ok, game_pid} ->
              {:ok, id, game_pid}

            {:error, reason} ->
              {:error, "error starting game: #{inspect(reason)}"}
          end
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec game_name(String.t()) :: {:via, Registry, {GameRegistry, binary}}
  defp game_name(id) when is_binary(id) do
    {:via, Registry, {GameRegistry, id}}
  end

  @spec trimmed_or_random_id(String.t()) :: String.t()
  defp trimmed_or_random_id(id) do
    case String.trim(id) do
      "" -> GameServer.random_id(8)
      trimmed -> trimmed
    end
  end

  @spec validate_id(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp validate_id(id) do
    if String.length(id) > 32 do
      {:error, "length is greater than 32 characters"}
    else
      {:ok, id}
    end
  end
end
