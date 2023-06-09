defmodule Tictactoe do
  @moduledoc """
  Global functions that depend on the whole system. Don't know where else to
  put them.
  """

  alias Tictactoe.GameRegistry
  alias Tictactoe.GameSupervisor
  alias Tictactoe.GameServer

  @spec lookup_or_start_game(String.t()) :: {:ok, GameServer.id(), pid}
  def lookup_or_start_game(id) when is_binary(id) do
    id = trimmed_or_random_id(id)

    case Registry.lookup(GameRegistry, id) do
      [{game_pid, nil}] ->
        true = Process.alive?(game_pid)
        {:ok, id, game_pid}

      [] ->
        {:ok, game_pid} =
          DynamicSupervisor.start_child(GameSupervisor, {GameServer, id: id, name: game_name(id)})

        {:ok, id, game_pid}
    end
  end

  @spec game_name(String.t()) :: {:via, Registry, {Tictactoe.GameRegistry, binary}}
  defp game_name(id) when is_binary(id) do
    {:via, Registry, {GameRegistry, id}}
  end

  defp trimmed_or_random_id(id) do
    case String.trim(id) do
      "" -> GameServer.random_id()
      trimmed -> trimmed
    end
  end
end
