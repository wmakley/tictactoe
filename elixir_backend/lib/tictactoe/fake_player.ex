defmodule Tictactoe.FakePlayer do
  @moduledoc """
  A fake player process, which can join a game and send chat messages,
  for use in tests.
  """
  use GenServer, restart: :temporary

  alias Tictactoe.GameServer

  require Logger

  def start(options \\ []) do
    Logger.debug(fn -> "FakePlayer.start(#{inspect(options)})" end)
    GenServer.start(__MODULE__, nil, options)
  end

  def start_link(options \\ []) do
    Logger.debug(fn -> "FakePlayer.start_link(#{inspect(options)})" end)
    GenServer.start_link(__MODULE__, nil, options)
  end

  def join_game(fake_player_pid, game_pid, player_name: player_name)
      when is_pid(fake_player_pid) do
    GenServer.call(fake_player_pid, {:join_game, game_pid, player_name})
  end

  def joined?(fake_player_pid) when is_pid(fake_player_pid) do
    GenServer.call(fake_player_pid, :joined?)
  end

  @impl true
  def init(_) do
    Logger.debug(fn -> "FakePlayer.init(pid: #{inspect(self())})" end)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:join_game, game_pid, player_name}, _from, _state)
      when is_pid(game_pid) and is_binary(player_name) do
    {:ok, player, game_state} = GameServer.join_game(game_pid, player_name)

    {:reply, {:ok, player, game_state}, %{player: player, game_pid: game_pid}}
  end

  def handle_call(:joined?, _from, state) do
    {:reply, Map.has_key?(state, :game_pid), state}
  end
end
