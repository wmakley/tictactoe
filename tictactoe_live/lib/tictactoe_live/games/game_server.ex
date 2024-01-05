defmodule TictactoeLive.Games.GameServer do
  @moduledoc """
  A game server process, which manages a single GameState.
  See: TictactoeLive.Games.GameState

  Monitors player connections. If the player process is killed,
  the player is removed from the game.
  """
  use GenServer, restart: :temporary

  require Logger

  alias TictactoeLive.Games.GameState

  @type id :: String.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    id = Keyword.get(opts, :id)
    start_link(id, Keyword.delete(opts, :id))
  end

  @spec start_link(id(), keyword()) :: GenServer.on_start()
  def start_link(id, opts) when is_binary(id) do
    Logger.debug("GameServer.start_link(#{inspect(id)}, #{inspect(opts)})")
    GenServer.start_link(__MODULE__, id, opts)
  end

  ## Client

  @doc """
  Join a game server as a player and subscribe to state changes.
  """
  @spec join_game_as_player(GenServer.server(), String.t()) ::
          {:error, String.t()}
          | {:ok, id(), :player, Tictactoe.Player.t(), :state, GameState.t()}
  def join_game_as_player(server, player_name) when is_binary(player_name) do
    case GenServer.call(server, {:join_game, player_name}) do
      {:ok, game_id, :player, _player, :state, _state} = result ->
        Phoenix.PubSub.subscribe(TictactoeLive.PubSub, "game:#{game_id}")
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec leave_game(GenServer.server()) :: :ok
  def leave_game(game_server) do
    GenServer.cast(game_server, {:disconnect, self()})
  end

  @spec add_chat_message(GenServer.server(), String.t()) ::
          {:ok, GameState.t()} | {:error, String.t()}
  def add_chat_message(pid, text) do
    GenServer.call(pid, {:add_chat_message, text})
  end

  @spec update_player_name(pid, String.t()) ::
          {:ok, String.t(), GameState.t()} | {:error, String.t()}
  def update_player_name(pid, new_name) do
    GenServer.call(pid, {:update_player_name, new_name})
  end

  @spec take_turn(pid, integer) :: {:ok, GameState.t()} | {:error, String.t()}
  def take_turn(pid, space) do
    GenServer.call(pid, {:take_turn, space})
  end

  @spec rematch(pid) :: {:ok, GameState.t()} | {:error, String.t()}
  def rematch(pid) do
    GenServer.call(pid, {:rematch})
  end

  @doc """
  Dump the server state.
  """
  @spec dump_state(pid) :: Map
  def dump_state(pid) do
    GenServer.call(pid, :dump_state)
  end

  ## Server

  @impl true
  def init(id) when is_binary(id) do
    Logger.info("#{inspect(self())} GameServer.init(#{inspect(id)})")

    {:ok,
     %{
       id: id,
       connections: %{},
       game: GameState.new()
     }}
  end

  @impl true
  def handle_call({:join_game, name} = params, {caller, _}, state) when is_pid(caller) do
    Logger.debug(
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, from: #{inspect(caller)})"
    )

    case GameState.add_player(state.game, name) do
      {:ok, player, game} ->
        {:reply, {:ok, state.id, :player, player, :state, game},
         state
         |> update_game_state(game)
         |> broadcast_state_to_players()
         |> add_connection(caller, player.id)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_player_name, new_name} = params, {pid, _} = from, state)
      when is_binary(new_name) do
    Logger.debug(
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(from)})"
    )

    with {:ok, player_id} <- get_player_id(state, pid),
         {:ok, normalized_name, game_state} <-
           GameState.update_player_name(state.game, player_id, new_name) do
      {:reply, {:ok, normalized_name, game_state},
       state
       |> update_game_state(game_state)
       |> broadcast_state_to_players()}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:add_chat_message, text} = msg, {pid, _}, state) do
    Logger.debug(
      "#{inspect(self())} GameServer.handle_call(#{inspect(msg)}, player: #{inspect(pid)})"
    )

    with {:ok, player_id} <- get_player_id(state, pid),
         {:ok, game_state} <- GameState.add_player_chat_message(state.game, player_id, text) do
      {:reply, {:ok, game_state},
       state
       |> update_game_state(game_state)
       |> broadcast_state_to_players()}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:take_turn, position} = params, {pid, _} = from, state)
      when is_integer(position) do
    Logger.debug(
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(from)})"
    )

    with {:ok, player_id} <- get_player_id(state, pid),
         {:ok, game_state} <- GameState.take_turn(state.game, player_id, position) do
      {:reply, {:ok, game_state},
       state
       |> update_game_state(game_state)
       |> broadcast_state_to_players()}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:rematch} = msg, {pid, _} = from, state) do
    Logger.debug("#{inspect(self())} GameServer.handle_call(#{inspect(msg)}, #{inspect(from)})")

    with {:ok, player_id} <- get_player_id(state, pid),
         {:ok, game_state} <- GameState.rematch(state.game, player_id) do
      {:reply, {:ok, game_state},
       state
       |> update_game_state(game_state)
       |> broadcast_state_to_players()}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Dump the state of the server, for debugging
  def handle_call(:dump_state, _from, state) do
    Logger.debug("#{inspect(self())} GameServer.dump_state()")
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:disconnect, pid} = params, state) do
    Logger.debug("#{inspect(self())} GameServer.handle_cast(#{inspect(params)})")

    {:noreply, remove_player(state, pid)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) when is_pid(pid) do
    # Logger.debug("#{inspect(self())} GameServer.handle_info(#{inspect(params)})")
    Logger.info("#{inspect(self())} GameServer: Player #{inspect(pid)} disconnected.")

    {:noreply, remove_player(state, pid)}
  end

  def handle_info(:terminate_if_empty, state) do
    if map_size(state.connections) == 0 do
      Logger.debug("#{inspect(self())} GameServer.handle_info(:terminate_if_empty) terminating")

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "#{inspect(self())} GameServer.terminate(#{inspect(reason)}, id: #{inspect(state.id)})"
    )
  end

  @spec random_id(integer()) :: String.t()
  def random_id(length) when is_integer(length) do
    for _ <- 1..length,
        into: "",
        do: random_char()
  end

  @spec random_char() :: String.t()
  defp random_char() do
    <<Enum.random(~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")>>
  end

  @spec update_game_state(map, GameState.t()) :: map
  defp update_game_state(state, game_state) do
    %{state | game: game_state}
  end

  defp remove_player(state, pid) when is_pid(pid) do
    Logger.debug("#{inspect(self())} GameServer.remove_player(#{inspect(pid)})")

    {:ok, player_id, state} = remove_connection(state, pid)

    {:ok, game} = GameState.remove_player(state.game, player_id)

    state
    |> update_game_state(game)
    |> broadcast_state_to_players()
    |> schedule_termination_if_empty()
  end

  defp schedule_termination_if_empty(state) do
    # Logger.debug(fn ->
    #   "#{inspect(self())} GameServer.schedule_termination_if_empty()"
    # end)

    if map_size(state.connections) == 0 do
      Process.send_after(self(), :terminate_if_empty, 60_000)
    end

    state
  end

  defp add_connection(state, pid, player_id) when is_pid(pid) and is_integer(player_id) do
    ref = Process.monitor(pid)
    %{state | connections: Map.put(state.connections, pid, {:ref, ref, :player_id, player_id})}
  end

  @spec get_player_id(map, pid) :: {:ok, integer} | {:error, String.t()}
  defp get_player_id(state, player_pid) when is_pid(player_pid) do
    case Map.get(state.connections, player_pid) do
      {:ref, _ref, :player_id, player_id} ->
        {:ok, player_id}

      nil ->
        {:error, "Player not found"}
    end
  end

  @spec remove_connection(any(), pid) :: {:ok, integer, any()}
  defp remove_connection(state, pid) when is_pid(pid) do
    Logger.debug("#{inspect(self())} GameServer.remove_connection(#{inspect(pid)})")

    {:ref, ref, :player_id, player_id} = Map.get(state.connections, pid)

    Process.demonitor(ref)

    {:ok, player_id,
     %{
       state
       | connections: Map.delete(state.connections, pid)
     }}
  end

  # Push state changes to pub-sub to allow for multiple observers.
  defp broadcast_state_to_players(state) do
    :ok =
      Phoenix.PubSub.broadcast(
        TictactoeLive.PubSub,
        "game:#{state.id}",
        {:game_state, state.id, state.game}
      )

    state
  end
end
