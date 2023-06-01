defmodule Tictactoe.GameServer do
  @moduledoc """
  A game server process, which manages a single game.
  See: Tictactoe.Game
  """
  use GenServer, restart: :temporary

  require Logger

  alias Tictactoe.Game

  @spec start_link(String.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(id) when is_binary(id) do
    GenServer.start_link(__MODULE__, id, [])
  end

  ## Client

  @spec join_game(pid, String.t()) ::
          {:error, String.t()} | {:ok, Tictactoe.Player.t(), Game.t()}
  def join_game(pid, name) when is_pid(pid) and is_binary(name) do
    GenServer.call(pid, {:join_game, name})
  end

  @spec leave_game(pid, pid) :: :ok
  def leave_game(game_server, pid) do
    GenServer.cast(game_server, {:leave_game, pid})
  end

  @spec add_chat_message(atom | pid | {atom, any} | {:via, atom, any}, integer, String.t()) ::
          {:ok, Game.t()} | {:error, String.t()}
  def add_chat_message(pid, player_id, text) do
    GenServer.call(pid, {:add_chat_message, player_id, text})
  end

  @doc """
  Dump the server state.
  """
  @spec dump_state(pid) :: any
  def dump_state(pid) do
    GenServer.call(pid, :dump_state)
  end

  ## Server

  @impl true
  def init(id) do
    # Logger.debug(fn -> "#{inspect(self())} GameServer.init(#{inspect(id)})" end)

    {:ok,
     %{
       connections: %{},
       game: Game.new(id)
     }}
  end

  @impl true
  def handle_call({:join_game, name} = params, {caller, _}, state) when is_pid(caller) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, from: #{inspect(caller)})"
    end)

    case Game.add_player(state.game, name) do
      {:ok, player, game} ->
        broadcast_state_to_players(state)

        {:reply, {:ok, player, game},
         %{
           state
           | game: game
         }
         |> add_connection(caller, player.id)}

      {:error, reason, game} ->
        {:reply, {:error, reason}, %{state | game: game}}
    end
  end

  def handle_call({:update_player_name, player_id, new_name} = params, caller, state)
      when is_integer(player_id) and is_binary(new_name) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(caller)})"
    end)

    case Game.update_player_name(state.game, player_id, new_name) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:add_chat_message, player_id, text} = params, caller, state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(caller)})"
    end)

    case Game.add_player_chat_message(state.game, player_id, text) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game} |> broadcast_state_to_players()}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:take_turn, player_id, position} = params, caller, state)
      when is_integer(player_id) and is_integer(position) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(caller)})"
    end)

    case Game.take_turn(state.game, player_id, position) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game} |> broadcast_state_to_players()}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Dump the state of the server, for debugging
  def handle_call(:dump_state, _from, state) do
    Logger.debug(fn -> "#{inspect(self())} GameServer.dump_state()" end)
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:disconnect, pid} = params, state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_cast(#{inspect(params)})"
    end)

    {:noreply, remove_player(state, pid)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason} = params, state) when is_pid(pid) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_info(#{inspect(params)})"
    end)

    {:noreply, remove_player(state, pid)}
  end

  defp remove_player(state, pid) when is_pid(pid) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.remove_player(#{inspect(pid)})"
    end)

    {:ok, player_id, state} = remove_connection(state, pid)

    {:ok, game} = Game.remove_player(state.game, player_id)

    %{state | game: game} |> broadcast_state_to_players()
  end

  defp add_connection(state, pid, player_id) when is_pid(pid) and is_integer(player_id) do
    ref = Process.monitor(pid)
    %{state | connections: Map.put(state.connections, pid, {ref, player_id})}
  end

  @spec remove_connection(any(), pid) :: {:ok, integer, any()}
  defp remove_connection(state, pid) when is_pid(pid) do
    Logger.debug("#{inspect(self())} GameServer.remove_connection(#{inspect(pid)})")

    {ref, player_id} = Map.get(state.connections, pid)

    Process.demonitor(ref)

    {:ok, player_id,
     %{
       state
       | connections: Map.delete(state.connections, pid)
     }}
  end

  defp broadcast_state_to_players(state) do
    connections = Map.keys(state.connections)

    Logger.debug(fn ->
      "#{inspect(self())} GameServer.broadcast_state_to_players(#{inspect(connections)})"
    end)

    Enum.each(connections, fn connection ->
      :ok = Process.send(connection, {:game_state, state.game}, [])
    end)

    state
  end
end
