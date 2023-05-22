defmodule Tictactoe.RegistrySupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Tictactoe.GameRegistry,
      {DynamicSupervisor, name: Tictactoe.GameSupervisor}
    ]

    # all games must be killed if registry dies, but not vice versa
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
