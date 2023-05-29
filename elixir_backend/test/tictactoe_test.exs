defmodule TictactoeTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tictactoe

  # test "help text" do
  #   conn = conn(:get, "/")
  #   conn = Tictactoe.Router.call(conn, [])
  #   assert conn.status == 200
  # end

  # ignored: the documentation isn't even right
  # test "websocket upgrade succeeds" do
  #   conn = conn(:get, "/ws")
  #   upgrades = Plug.Test.send_upgrades(conn)
  #   assert {:websocket, [opt: :value]} in upgrades
  # end
end
