defmodule Tictactoe.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Tictactoe.RegistrySupervisor,
      {Bandit, plug: Tictactoe.Router, scheme: :http, port: 3000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
