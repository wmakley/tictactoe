defmodule TictactoeBackend do
  require Logger

  @moduledoc """
  Documentation for `TictactoeBackend`.
  """

  use Application

  alias TictactoeBackend.Router

  def start(_type, _args) do
    server = {Bandit, plug: Router, scheme: :http, port: 3000}
    {:ok, _} = Supervisor.start_link([server], strategy: :one_for_one)
    Logger.info("Plug now running on localhost:3000")
    Process.sleep(:infinity)
  end
end
