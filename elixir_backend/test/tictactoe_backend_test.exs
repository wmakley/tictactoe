defmodule TictactoeBackendTest do
  use ExUnit.Case
  doctest TictactoeBackend

  test "greets the world" do
    assert TictactoeBackend.hello() == :world
  end
end
