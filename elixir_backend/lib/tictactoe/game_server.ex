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

  @spec add_player(pid, String.t()) :: {:error, String.t()} | {:ok, Tictactoe.Player.t()}
  def add_player(pid, name) when is_pid(pid) and is_binary(name) do
    GenServer.call(pid, {:add_player, name})
  end

  @spec disconnect(pid, integer) :: :ok
  def disconnect(pid, player_id) when is_pid(pid) and is_integer(player_id) do
    GenServer.cast(pid, {:disconnect, player_id})
  end

  @spec handle_message_from_browser(pid, integer, map) :: any
  def handle_message_from_browser(pid, player_id, %{} = json)
      when is_pid(pid) and is_integer(player_id) do
    case json do
      %{"ChatMsg" => text} ->
        GenServer.call(pid, {:add_chat_message, player_id, text})

        # TODO
    end
  end

  ## Private Handlers

  @impl true
  def init(id) do
    {:ok, Game.new(id)}
  end

  @impl true
  def handle_call({:add_player, name}, _from, game) do
    case Game.add_player(game, name) do
      {:ok, player, game} ->
        {:reply, {:ok, player}, game}

      {:error, reason, game} ->
        {:reply, {:error, reason}, game}
    end
  end

  @impl true
  def handle_call({:update_player_name, player_id, new_name}, _from, game)
      when is_integer(player_id) and is_binary(new_name) do
    case Game.update_player_name(game, player_id, new_name) do
      {:ok, game} ->
        {:reply, {:ok, game}, game}

      {:error, reason} ->
        {:reply, {:error, reason}, game}
    end
  end

  @impl true
  def handle_call({:add_chat_message, player_id, text}, _from, state) do
    case Game.add_player_chat_message(state, player_id, text) do
      {:ok, game} ->
        {:reply, {:ok, game}, game}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:take_turn, player_id, position}, _from, game)
      when is_integer(player_id) and is_integer(position) do
    case Game.take_turn(game, player_id, position) do
      {:ok, game} ->
        {:reply, {:ok, game}, game}

      {:error, reason} ->
        {:reply, {:error, reason}, game}
    end
  end

  @impl true
  def handle_cast({:disconnect, player_id}, game) do
    case Game.remove_player(game, player_id) do
      {:ok, game} ->
        {:noreply, game}

      {:error, reason} ->
        Logger.error(fn ->
          "Failed to remove player id #{inspect(player_id)}: #{inspect(reason)}"
        end)

        {:noreply, game}
    end
  end
end
