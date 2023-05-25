defmodule Tictactoe.GameRegistry do
  @moduledoc """
  A simple registry of all active game pids, indexed by their id/join token.
  Could use the built-in Registry abstraction, but this is more fun and
  educational.
  """
  use GenServer

  require Logger

  alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: Tictactoe.GameRegistry)
  end

  @impl true
  def init(_init_arg) do
    pids = :ets.new(:game_pids, [:named_table, :set, :public])
    refs = :ets.new(:game_refs, [:named_table, :set, :public])
    {:ok, {pids, refs}}
  end

  @doc """
  Lookup a game pid by its id/join token. If the game is not found, start a new one.
  Returns the pid of the game.
  """
  @spec lookup_or_start_game(String.t()) :: {:ok, pid}
  def lookup_or_start_game(id) when is_binary(id) do
    # Logger.debug(fn -> "GameRegistry.lookup_or_start_game: #{inspect(id)}" end)

    case lookup(id) do
      {:ok, pid} ->
        {:ok, pid}

      nil ->
        # Logger.debug(fn ->
        #   "GameRegistry.lookup_or_start_game: #{inspect(id)}: starting new game"
        # end)

        {:ok, pid} = DynamicSupervisor.start_child(Tictactoe.GameSupervisor, {GameServer, id})

        GenServer.cast(GameRegistry, {:monitor_game, id, pid})

        :ets.insert(:game_pids, {id, pid})
        {:ok, pid}
    end
  end

  @spec lookup(String.t()) :: {:ok, pid} | nil
  def lookup(id) when is_binary(id) do
    case :ets.lookup(:game_pids, id) do
      [{^id, pid}] ->
        # Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: #{inspect(pid)}" end)
        {:ok, pid}

      [] ->
        # Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: not found" end)
        nil
    end
  end

  ## Private handlers

  @impl true
  def handle_cast({:monitor_game, id, pid}, state) when is_binary(id) and is_pid(pid) do
    # Logger.debug(fn ->
    #   "GameRegistry.handle_cast: monitor_game: id=#{inspect(id)} pid=#{inspect(pid)}"
    # end)

    ref = Process.monitor(pid)
    :ets.insert(:game_refs, {ref, id})
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    # Logger.debug(fn ->
    #   "GameRegistry.handle_info: #{inspect(ref)}: #{inspect(pid)}: process down: #{inspect(reason)}}"
    # end)

    Task.start_link(fn ->
      case :ets.lookup(:game_refs, ref) do
        [{^ref, id}] ->
          Logger.debug(fn -> "GameRegistry.handle_info: cleaning up #{inspect(id)}" end)
          :ets.delete(:game_pids, id)
          :ets.delete(:game_refs, ref)

        [] ->
          Logger.warn(fn ->
            "GameRegistry.handle_info: #{inspect(ref)}: #{inspect(pid)}: not found"
          end)
      end
    end)

    {:noreply, state}
  end
end
