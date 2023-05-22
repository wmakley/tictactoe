defmodule Tictactoe.GameServer do
  use GenServer, restart: :temporary

  alias Tictactoe.Game

  @spec start_link(String.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(id) when is_binary(id) do
    GenServer.start_link(__MODULE__, id, [])
  end

  ## Public API

  def add_player(pid, name) do
    GenServer.call(pid, {:add_player, name})
  end

  ## Handlers

  @impl true
  def init(id) do
    {:ok, Game.new(id)}
  end

  @impl true
  def terminate(reason, state) do
    Tictactoe.GameRegistry.delete_game(state.id)
    require Logger
    Logger.info("Game #{state.id} terminated, reason: #{reason}")
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
end
