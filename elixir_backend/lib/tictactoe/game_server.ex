defmodule Tictactoe.GameServer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def new_game(pid, name) do
    GenServer.call(pid, {:new_game, name})
  end
end
