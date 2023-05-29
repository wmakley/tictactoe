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

  @spec add_player(pid, String.t()) ::
          {:error, String.t()} | {:ok, Tictactoe.Player.t(), Game.t()}
  def add_player(pid, name) when is_pid(pid) and is_binary(name) do
    GenServer.call(pid, {:add_player, name})
  end

  @spec disconnect(pid, integer) :: :ok
  def disconnect(pid, player_id) when is_pid(pid) and is_integer(player_id) do
    GenServer.cast(pid, {:disconnect, player_id})
  end

  @spec add_chat_message(atom | pid | {atom, any} | {:via, atom, any}, integer, String.t()) ::
          {:ok, Game.t()} | {:error, String.t()}
  def add_chat_message(pid, player_id, text) do
    GenServer.call(pid, {:add_chat_message, player_id, text})
  end

  ## Private Handlers

  @impl true
  def init(id) do
    {:ok,
     %{
       subscriptions: [],
       game: Game.new(id)
     }}
  end

  @impl true
  def handle_call({:add_player, name}, caller, state) do
    case Game.add_player(state.game, name) do
      {:ok, player, game} ->
        {:reply, {:ok, player, game},
         %{
           state
           | game: game,
             subscriptions: [{:player, caller, player.id} | state.subscriptions]
         }}

      {:error, reason, game} ->
        {:reply, {:error, reason}, %{state | game: game}}
    end
  end

  @impl true
  def handle_call({:update_player_name, player_id, new_name}, _from, state)
      when is_integer(player_id) and is_binary(new_name) do
    case Game.update_player_name(state.game, player_id, new_name) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:add_chat_message, player_id, text}, _from, state) do
    case Game.add_player_chat_message(state.game, player_id, text) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:take_turn, player_id, position}, _from, state)
      when is_integer(player_id) and is_integer(position) do
    case Game.take_turn(state.game, player_id, position) do
      {:ok, game} ->
        {:reply, {:ok, game}, %{state | game: game}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:disconnect, player_id}, %{game: game} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} GameServer.handle_cast({:disconnect, #{inspect(player_id)}})"
    end)

    case Game.remove_player(game, player_id) do
      {:ok, game} ->
        {:noreply, %{state | game: game}}

      {:error, reason} ->
        Logger.error(fn ->
          "Failed to remove player id #{inspect(player_id)}: #{inspect(reason)}"
        end)

        {:noreply, state}
    end
  end
end
