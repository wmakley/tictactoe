defmodule Tictactoe.GameRegistryTest do
  use ExUnit.Case, async: false

  require Logger

  # alias Tictactoe.RegistrySupervisor
  alias Tictactoe.GameRegistry

  setup do
    {:ok, registry} = start_supervised(GameRegistry, restart: :temporary)
    # Logger.debug("registry pid: #{inspect(registry)}")
    {:ok, %{registry: registry}}
  end

  test "lookup_or_start_game adds games to the registry or returns them if they exist", %{
    registry: registry
  } do
    {:ok, pid} = GameRegistry.lookup_or_start_game(registry, "dupe-test")

    {:ok, pid2} = GameRegistry.lookup_or_start_game(registry, "dupe-test")

    assert pid == pid2
  end

  test "games are removed from the registry if they crash", %{
    registry: registry
  } do
    {:ok, pid} = GameRegistry.lookup_or_start_game(registry, "will-crash")
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        # Logger.debug(fn -> "Test pid #{inspect(pid)} exited: #{inspect(reason)}" end)
        :ok

      other ->
        raise "unexpected message: #{inspect(other)}"
    end

    Process.sleep(100)
    assert GameRegistry.lookup_pid("will-crash") == nil
  end

  test "registry stays up if games crash", %{registry: registry} do
    # start two games
    {:ok, pid} = GameRegistry.lookup_or_start_game(registry, "test")
    {:ok, pid2} = GameRegistry.lookup_or_start_game(registry, "test2")

    # kill the first one
    :ok = GenServer.stop(pid, :shutdown)
    Process.sleep(100)

    assert Process.alive?(registry)

    # second game should still exist in registry
    {:ok, pid3} = GameRegistry.lookup_or_start_game(registry, "test2")
    assert pid3 == pid2
    assert Process.alive?(pid2)
  end

  test "all games are killed if registry crashes", %{registry: registry} do
    # start two games
    {:ok, pid} = GameRegistry.lookup_or_start_game(registry, "game1")
    {:ok, pid2} = GameRegistry.lookup_or_start_game(registry, "game2")

    # kill the registry
    :ok = GenServer.stop(registry, :shutdown)

    # wait a second for the registry to die and kill its children
    Process.sleep(100)

    refute Process.alive?(registry)

    # both games should be dead
    refute Process.alive?(pid)
    refute Process.alive?(pid2)
  end
end
