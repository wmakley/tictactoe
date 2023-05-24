defmodule Tictactoe.GameServer do
  use GenServer, restart: :temporary

  require Logger

  alias Tictactoe.Game
  # alias Tictactoe.GameRegistry

  @spec start_link(String.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(id) when is_binary(id) do
    GenServer.start_link(__MODULE__, id, [])
  end

  ## Public API

  def add_player(pid, name) when is_pid(pid) and is_binary(name) do
    GenServer.call(pid, {:add_player, name})
  end

  ## Private Handlers

  @impl true
  def init(id) do
    {:ok, Game.new(id)}
  end

  # @impl true
  # def terminate(reason, state) do
  #   Logger.debug(fn ->
  #     "GameServer.terminate: #{inspect(state.id)}, reason: #{inspect(reason)}"
  #   end)

  #   # GameRegistry.delete_game(state.id)
  # end

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
