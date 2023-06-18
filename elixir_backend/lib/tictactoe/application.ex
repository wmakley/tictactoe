defmodule Tictactoe.Application do
  use Application

  def start(_type, _args) do
    Tictactoe.System.start_link(:ok)
  end
end
