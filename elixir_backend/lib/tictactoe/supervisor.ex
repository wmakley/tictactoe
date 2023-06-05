defmodule Tictactoe.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    port = Application.fetch_env!(:tictactoe, :port)

    children = [
      {Tictactoe.GameRegistry, name: Tictactoe.GameRegistry},
      {Bandit, plug: Tictactoe.Router, scheme: :http, port: port}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
