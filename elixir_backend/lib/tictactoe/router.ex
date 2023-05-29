defmodule Tictactoe.Router do
  use Plug.Router

  require Logger

  unless Mix.env() == :test do
    # Annoyingly noisy when testing, as there are few plug tests
    plug(Plug.Logger)
  end

  plug(:match)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart], validate_utf8: true)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, """
    Use the JavaScript console to interact using websockets

    let sock = new WebSocket("ws://localhost:3000/ws")
    sock.addEventListener("message", console.log)
    sock.addEventListener("open", () => sock.send("ping"))
    """)
  end

  get "/ws" do
    # Logger.debug(fn -> inspect(conn) end)

    name = Map.get(conn.params, "name", "")
    token = Map.get(conn.params, "token", "")

    conn
    |> WebSockAdapter.upgrade(Tictactoe.PlayerConn, [name: name, token: token], timeout: 60_000)
    |> halt()
  end

  get "/echo" do
    conn
    |> WebSockAdapter.upgrade(Tictactoe.EchoServer, [], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "404 Not found.\n")
  end
end
