defmodule Tictactoe.Router do
  use Plug.Router

  unless Mix.env() == :test do
    # Annoyingly noisy when testing, as there are few plug tests
    plug(Plug.Logger)
  end

  plug(:match)
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
    conn
    |> WebSockAdapter.upgrade(Tictactoe.EchoServer, [], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "404 Not found.\n")
  end
end
