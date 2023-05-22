defmodule Tictactoe.GameRegistryTest do
  use ExUnit.Case, async: false

  alias Tictactoe.GameRegistry

  test "lookup_or_start_game adds games to the registry or returns them if they exist" do
    {:ok, pid} = GameRegistry.lookup_or_start_game("test")

    {:ok, pid2} = GameRegistry.lookup_or_start_game("test")

    assert pid == pid2
  end

  test "games are removed from the registry if they crash" do
    {:ok, pid} = GameRegistry.lookup_or_start_game("test")

    :ok = GenServer.stop(pid, :shutdown)
    {:ok, pid2} = GameRegistry.lookup_or_start_game("test")

    refute pid == pid2
  end
end
