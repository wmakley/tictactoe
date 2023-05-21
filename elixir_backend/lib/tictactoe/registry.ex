defmodule Tictactoe.Registry do
  @moduledoc """
  A simple registry of all games.
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def join_or_new_game(pid, name) do
    GenServer.call(pid, {:join_or_new_game, name})
  end

  defp handle_call({:join_or_new_game, name}, _from, state) do
    state
  end
end
