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

  ## Public API

  @spec join_game(pid, String.t()) ::
          {:error, String.t()} | {:ok, Tictactoe.Player.t(), Game.t()}
  def join_game(pid, name) when is_pid(pid) and is_binary(name) do
    GenServer.call(pid, {:join_game, name})
  end

  @spec disconnect(pid, pid, integer) :: :ok
  def disconnect(pid, caller, player_id) do
    GenServer.cast(pid, {:disconnect, caller, player_id})
  end

  @spec add_chat_message(atom | pid | {atom, any} | {:via, atom, any}, integer, String.t()) ::
          {:ok, Game.t()} | {:error, String.t()}
  def add_chat_message(pid, player_id, text) do
    GenServer.call(pid, {:add_chat_message, player_id, text})
  end

  ## Private Handlers

  @impl true
  def init(id) do
    Logger.debug(fn -> "#{inspect(self())} GameServer.init(#{inspect(id)})" end)

    {:ok,
     %{
       subscriptions: [],
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
        notify_subscribers(state)

        {:reply, {:ok, player, game},
         %{
           state
           | game: game,
             subscriptions: [caller | state.subscriptions]
         }}

      {:error, reason, game} ->
        {:reply, {:error, reason}, %{state | game: game}}
    end
  end

  @impl true
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

  @impl true
  def handle_call({:add_chat_message, player_id, text} = params, caller, state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_call(#{inspect(params)}, #{inspect(caller)})"
    end)

    case Game.add_player_chat_message(state.game, player_id, text) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game} |> notify_subscribers()}

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
        {:reply, {:ok, game}, %{state | game: game} |> notify_subscribers()}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:disconnect, caller, player_id} = params, %{game: game} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_cast(#{inspect(params)})"
    end)

    state = remove_subscription(caller, state)

    case Game.remove_player(game, player_id) do
      {:ok, game} ->
        {:noreply, %{state | game: game} |> notify_subscribers()}

      {:error, reason} ->
        Logger.error(fn ->
          "Failed to remove player id #{inspect(player_id)}: #{inspect(reason)}"
        end)

        {:noreply, state}
    end
  end

  defp notify_subscribers(state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.notify_subscribers(#{inspect(state.subscriptions)})"
    end)

    Enum.each(state.subscriptions, fn subscriber ->
      :ok = Process.send(subscriber, {:game_state, state.game}, [])
    end)

    state
  end

  defp remove_subscription(pid, state) do
    Logger.debug("#{inspect(self())} GameServer.remove_subscription(#{inspect(pid)})")

    %{
      state
      | subscriptions:
          Enum.filter(state.subscriptions, fn subscriber ->
            subscriber != pid
          end)
    }
  end
end
