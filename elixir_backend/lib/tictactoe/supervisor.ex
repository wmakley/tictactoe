defmodule Tictactoe.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {Tictactoe.Registry, name: Tictactoe.Registry},
      {Bandit, plug: Tictactoe.Router, scheme: :http, port: 3000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
