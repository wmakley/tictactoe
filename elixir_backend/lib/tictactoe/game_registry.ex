defmodule Tictactoe.GameRegistry do
  @moduledoc """
  A simple registry of all active game pids, indexed by their id/join token.
  Could use the built-in Registry abstraction, but this is more fun and
  educational.
  """
  use GenServer

  require Logger

  alias Tictactoe.GameServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :supervisor
    }
  end

  @impl true
  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    pids = :ets.new(:game_pids, [:named_table, :set, :protected, read_concurrency: true])
    ids = :ets.new(:game_ids, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, {pids, ids}}
  end

  @doc """
  Lookup a game from the default global registry.
  """
  @spec lookup_or_start_game(String.t()) :: {:ok, String.t(), pid}
  def lookup_or_start_game(id) do
    lookup_or_start_game(__MODULE__, id)
  end

  @doc """
  Lookup a game pid by its id/join token. If the game is not found, start a new
  one. Returns the id and pid of the game.
  """
  @spec lookup_or_start_game(pid | atom, String.t()) :: {:ok, String.t(), pid}
  def lookup_or_start_game(registry, id) when is_binary(id) do
    # Perform a concurrent lookup first, before performing
    # a synchronized start.

    id =
      case String.trim(id) do
        "" ->
          random_id()

        trimmed ->
          trimmed
      end

    case lookup_pid(id) do
      {:ok, pid} ->
        true = Process.alive?(pid)
        {:ok, id, pid}

      nil ->
        {:ok, pid} = GenServer.call(registry, {:lookup_or_start_game, id})
        {:ok, id, pid}
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

  @doc """
  Start a new game if not registered and register it, returning the pid. As it is synchronized, multiple games may not be started
  at once with the same id.
  """
  @impl true
  def handle_call({:lookup_or_start_game, id}, _caller, state) do
    case lookup_pid(id) do
      {:ok, pid} ->
        {:reply, {:ok, pid}, state}

      nil ->
        {:ok, pid} = start_game(id)
        {:reply, {:ok, pid}, state}
    end
  end

  defp start_game(id) do
    {:ok, pid} = GameServer.start_link(id)
    :ets.insert(:game_pids, {id, pid})
    :ets.insert(:game_ids, {pid, id})
    {:ok, pid}
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, state) do
    # Logger.debug(fn ->
    #   "GameRegistry.handle_info: :EXIT #{inspect(pid)}: #{inspect(reason)}"
    # end)

    # Task.start(fn ->
    unregister_game(pid)
    # end)

    {:noreply, state}
  end

  @spec random_id() :: String.t()
  defp random_id() do
    for _ <- 1..7,
        into: "",
        do: random_char()
  end

  @spec random_char() :: String.t()
  defp random_char() do
    <<Enum.random(~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")>>
  end

  defp unregister_game(pid) when is_pid(pid) do
    case lookup_id(pid) do
      {:ok, id} ->
        # Logger.debug(fn -> "GameRegistry.unregister_game: deleting #{inspect(id)}" end)
        :ets.delete(:game_pids, id)

      nil ->
        Logger.warn("GameRegistry.unregister_game: #{inspect(pid)}: not found")

        nil
    end

    :ets.delete(:game_ids, pid)
  end
end
