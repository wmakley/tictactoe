defmodule Tictactoe.GameRegistryTest do
  use ExUnit.Case, async: false

  require Logger

  alias Tictactoe.RegistrySupervisor
  alias Tictactoe.GameRegistry

  setup do
    on_exit(fn -> Logger.debug("test on_exit") end)
    {:ok, %{registry_supervisor: start_supervised!(RegistrySupervisor)}}
  end

  # test "lookup_or_start_game adds games to the registry or returns them if they exist" do
  #   {:ok, pid} = GameRegistry.lookup_or_start_game("dupe-test")

  #   {:ok, pid2} = GameRegistry.lookup_or_start_game("dupe-test")

  #   assert pid == pid2
  # end

  test "games are removed from the registry if they crash" do
    {:ok, pid} = GameRegistry.lookup_or_start_game("will-crash")
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} ->
        Logger.debug(fn -> "game process exited: #{inspect(reason)}" end)
    end

    # Process.sleep(1000)
    assert GameRegistry.lookup("will-crash") == nil
  end
end
