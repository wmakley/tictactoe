defmodule Tictactoe.Application do
  use Application

  def start(_type, _args) do
    Tictactoe.Supervisor.start_link(name: Tictactoe.Supervisor)
  end
end
