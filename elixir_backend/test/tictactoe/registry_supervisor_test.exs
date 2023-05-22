defmodule Tictactoe.RegistrySupervisorTest do
  use ExUnit.Case, async: false

  alias Tictactoe.GameRegistry

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
    Process.sleep(1000)

    # both games should be dead
    refute Process.alive?(pid)
    refute Process.alive?(pid2)
  end
end
