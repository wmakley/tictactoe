defmodule Tictactoe.GameRegistry do
  @moduledoc """
  A simple registry of all active game pids, indexed by their id/join token.
  Could use the built-in Registry abstraction, but this is more fun and
  educational.
  """
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: Tictactoe.GameRegistry)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(__MODULE__, [:named_table, :set, :public])
    {:ok, nil}
  end

  @doc """
  Lookup a game pid by its id/join token. If the game is not found, start a new one.
  Returns the pid of the game.
  """
  @spec lookup_or_start_game(String.t()) :: {:ok, pid}
  def lookup_or_start_game(id) do
    case :ets.lookup(__MODULE__, id) do
      [{^id, pid}] ->
        {:ok, pid}

      [] ->
        {:ok, pid} =
          DynamicSupervisor.start_child(Tictactoe.GameSupervisor, {Tictactoe.GameServer, id})

        :ets.insert(__MODULE__, {id, pid})
        {:ok, pid}
    end
  end

  # TODO: should only be able to be called when game process terminates
  @spec delete_game(String.t()) :: true
  def delete_game(id) do
    :ets.delete(__MODULE__, id)
  end
end
