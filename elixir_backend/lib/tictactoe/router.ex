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

  get "/ws" do
    # Logger.debug(fn -> inspect(conn) end)

    name = Map.get(conn.params, "name", "")
    token = Map.get(conn.params, "token", "")

    conn
    |> WebSockAdapter.upgrade(Tictactoe.PlayerConn, [name: name, token: token], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "404 Not found.\n")
  end
end
