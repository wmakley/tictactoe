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
    pids = :ets.new(:pids, [:named_table, :set, :public])
    refs = :ets.new(:refs, [:named_table, :set, :protected])
    {:ok, {pids, refs}}
  end

  @doc """
  Lookup a game pid by its id/join token. If the game is not found, start a new one.
  Returns the pid of the game.
  """
  @spec lookup_or_start_game(String.t()) :: {:ok, pid}
  def lookup_or_start_game(id) when is_binary(id) do
    Logger.debug(fn -> "GameRegistry.lookup_or_start_game: #{inspect(id)}" end)

    case lookup(id) do
      {:ok, pid} ->
        {:ok, pid}

      nil ->
        Logger.debug(fn ->
          "GameRegistry.lookup_or_start_game: #{inspect(id)}: starting new game"
        end)

        {:ok, pid} = DynamicSupervisor.start_child(Tictactoe.GameSupervisor, {GameServer, id})

        GenServer.cast(GameRegistry, {:monitor_game, id, pid})

        :ets.insert(:pids, {id, pid})
        {:ok, pid}
    end
  end

  @spec lookup(String.t()) :: {:ok, pid} | nil
  def lookup(id) when is_binary(id) do
    case :ets.lookup(:pids, id) do
      [{^id, pid}] ->
        Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: #{inspect(pid)}" end)
        {:ok, pid}

      [] ->
        Logger.debug(fn -> "GameRegistry.lookup: #{inspect(id)}: not found" end)
        nil
    end
  end

  # TODO: should only be able to be called when game process terminates
  # @spec delete_game(String.t()) :: :ok
  # def delete_game(id) when is_binary(id) do
  #   Logger.debug(fn -> "GameRegistry.delete_game: #{inspect(id)}" end)
  #   :ets.delete(__MODULE__, id)
  #   :ok
  # end

  @impl true
  def handle_cast({:monitor_game, id, pid}, state) when is_binary(id) and is_pid(pid) do
    Logger.debug(fn ->
      "GameRegistry.handle_cast: monitor_game: id=#{inspect(id)} pid=#{inspect(pid)}"
    end)

    ref = Process.monitor(pid)
    :ets.insert(:refs, {ref, id})
    state
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.debug(fn ->
      "GameRegistry.handle_info: #{inspect(ref)}: #{inspect(pid)}: process down: #{inspect(reason)}}"
    end)

    spawn(fn ->
      case :ets.lookup(:refs, ref) do
        [{^ref, id}] ->
          "GameRegistry.handle_info: cleaning up #{inspect(id)}"
          :ets.delete(:pids, id)
          :ets.delete(:refs, ref)

        [] ->
          Logger.warn(fn ->
            "GameRegistry.handle_info: #{inspect(ref)}: #{inspect(pid)}: not found"
          end)
      end
    end)

    {:noreply, state}
  end
end
