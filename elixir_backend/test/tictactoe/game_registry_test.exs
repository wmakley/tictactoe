defmodule Tictactoe.GameRegistryTest do
  use ExUnit.Case, async: false

  require Logger

  alias Tictactoe.RegistrySupervisor
  alias Tictactoe.GameRegistry

  setup do
    {:ok, %{registry: start_supervised!(GameRegistry)}}
  end

  test "lookup_or_start_game adds games to the registry or returns them if they exist" do
    {:ok, pid} = GameRegistry.lookup_or_start_game("dupe-test")

    {:ok, pid2} = GameRegistry.lookup_or_start_game("dupe-test")

    assert pid == pid2
  end

  test "games are removed from the registry if they crash" do
    {:ok, pid} = GameRegistry.lookup_or_start_game("will-crash")
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} ->
        Logger.debug(fn -> "Test pid #{inspect(pid)} exited: #{inspect(reason)}" end)
        :ok

      other ->
        raise "unexpected message: #{inspect(other)}"
    end

    Process.sleep(100)
    assert GameRegistry.lookup_pid("will-crash") == nil
  end

  test "registry stays up if games crash" do
    # start two games
    {:ok, pid} = GameRegistry.lookup_or_start_game("test")
    {:ok, pid2} = GameRegistry.lookup_or_start_game("test2")

    # kill the first one
    :ok = GenServer.stop(pid, :shutdown)

    # second game should still exist in registry
    {:ok, pid3} = GameRegistry.lookup_or_start_game("test2")
    assert pid3 == pid2
    assert Process.alive?(pid2)
  end

  test "all games are killed if registry crashes" do
    # start two games
    {:ok, pid} = GameRegistry.lookup_or_start_game("game1")
    {:ok, pid2} = GameRegistry.lookup_or_start_game("game2")

    # kill the registry
    :ok = GenServer.stop(Tictactoe.GameRegistry, :shutdown)

    # need to wait a second for supervisor to restart the registry
    Process.sleep(100)

    # both games should be dead
    refute Process.alive?(pid)
    refute Process.alive?(pid2)
  end
end
