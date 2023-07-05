defmodule TictactoeTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tictactoe

  # System tests:

  test "starting a new game with specific id" do
    {:ok, id, pid} = Tictactoe.lookup_or_start_game("123")
    assert id == "123"
    assert Process.alive?(pid)
  end

  test "starting a new game with random id" do
    {:ok, id, pid} = Tictactoe.lookup_or_start_game("")
    assert String.length(id) > 0
    assert Process.alive?(pid)
  end

  # Router tests:

  alias Tictactoe.Router

  test "GET /robots.txt" do
    conn = conn(:get, "/robots.txt")
    conn = Router.call(conn, [])
    assert conn.status == 200
    assert conn.resp_body == "User-agent: *\nDisallow: /\n"
  end

  test "GET /health" do
    conn = conn(:get, "/health")
    conn = Router.call(conn, [])
    assert conn.status == 200
    assert conn.resp_body == "OK\n"
  end

  test "OPTIONS /" do
    conn = conn(:options, "/")
    conn = Router.call(conn, [])
    assert conn.status == 204
    assert conn.resp_body == ""

    assert conn.resp_headers == [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"access-control-allow-origin", "http://localhost:5173"},
             {"access-control-allow-methods", "GET, OPTIONS"},
             {"access-control-allow-headers", "Content-Type"},
             {"access-control-max-age", "3600"}
           ]
  end

  test "GET /" do
    conn = conn(:get, "/")
    conn = Router.call(conn, [])
    assert conn.status == 302

    assert conn.resp_body =~
             ~r{<html><body>You are being <a href=\"http://localhost:5173\">redirected</a>.</body></html>}
  end

  # ignored: the documentation isn't even right
  # test "websocket upgrade succeeds" do
  #   conn = conn(:get, "/ws")
  #   conn = Router.call(conn, [])
  #   assert conn.status == 200
  #   #   upgrades = Plug.Test.send_upgrades(conn)
  #   #   assert {:websocket, [opt: :value]} in upgrades
  # end
end
