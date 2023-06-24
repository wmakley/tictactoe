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
    url = Application.get_env(:tictactoe, :frontend_url)
    html = Plug.HTML.html_escape(url)

    conn
    |> put_resp_header("location", url)
    |> put_resp_header("content-type", "text/html")
    |> send_resp(
      conn.status || 302,
      "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"
    )
  end

  options "/" do
    conn
    |> put_resp_header(
      "Access-Control-Allow-Origin",
      Application.get_env(:tictactoe, :frontend_url)
    )
    |> put_resp_header("Access-Control-Allow-Methods", "GET, OPTIONS")
    |> put_resp_header("Access-Control-Allow-Headers", "Content-Type")
    |> put_resp_header("Access-Control-Max-Age", "3600")
    |> send_resp(204, "")
  end

  get "/health" do
    send_resp(conn, 200, "OK\n")
  end

  get "/robots.txt" do
    send_resp(conn, 200, "User-agent: *\nDisallow: /\n")
  end

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
