defmodule Tictactoe.GameRegistry do
  @moduledoc """
  A simple registry of all active game pids, indexed by their id/join token.
  Could use the built-in Registry abstraction, but this is more fun and
  educational.
  """
  use GenServer

  require Logger

  # alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: Tictactoe.GameRegistry)
  end

  @impl true
  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    pids = :ets.new(:game_pids, [:named_table, :set, :public])
    ids = :ets.new(:game_ids, [:named_table, :set, :public])
    {:ok, {pids, ids}}
  end

  @doc """
  Lookup a game pid by its id/join token. If the game is not found, start a new one.
  Returns the pid of the game.
  """
  @spec lookup_or_start_game(String.t()) :: {:ok, pid}
  def lookup_or_start_game(id) when is_binary(id) do
    # Logger.debug(fn -> "GameRegistry.lookup_or_start_game: #{inspect(id)}" end)

    case lookup_pid(id) do
      {:ok, pid} ->
        {:ok, pid}

      nil ->
        # Logger.debug(fn ->
        #   "GameRegistry.lookup_or_start_game: #{inspect(id)}: starting new game"
        # end)

        # {:ok, pid} = DynamicSupervisor.start_child(Tictactoe.GameSupervisor, {GameServer, id})
        {:ok, pid} = GameServer.start_link(id)

        # GenServer.cast(GameRegistry, {:monitor_game, id, pid})

        :ets.insert(:game_pids, {id, pid})
        :ets.insert(:game_ids, {pid, id})
        {:ok, pid}
    end
  end

  @spec lookup_pid(String.t()) :: {:ok, pid} | nil
  def lookup_pid(id) when is_binary(id) do
    case :ets.lookup(:game_pids, id) do
      [{^id, pid}] ->
        # Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: #{inspect(pid)}" end)
        {:ok, pid}

      [] ->
        # Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: not found" end)
        nil
    end
  end

  @spec lookup_id(pid) :: {:ok, String.t()} | nil
  def lookup_id(pid) when is_pid(pid) do
    case :ets.lookup(:game_ids, pid) do
      [{^pid, id}] ->
        {:ok, id}

      [] ->
        nil
    end
  end

  ## Private handlers

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug(fn ->
      "GameRegistry.handle_info: :EXIT #{inspect(pid)}: #{inspect(reason)}"
    end)

    unregister_game(pid)

    {:noreply, state}
  end

  defp unregister_game(pid) when is_pid(pid) do
    case lookup_id(pid) do
      {:ok, id} ->
        Logger.debug(fn -> "GameRegistry.handle_info: cleaning up #{inspect(id)}" end)
        :ets.delete(:game_pids, id)
        :ets.delete(:game_ids, pid)

      nil ->
        Logger.warn(fn ->
          "GameRegistry.unregister_game: #{inspect(pid)}: not found"
        end)
    end
  end
end
