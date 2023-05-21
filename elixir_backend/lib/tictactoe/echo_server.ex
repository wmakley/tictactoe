defmodule Tictactoe.EchoServer do
  def init(options) do
    {:ok, options}
  end

  def handle_in({"ping", [opcode: :text]}, state) do
    {:reply, :ok, {:text, "pong"}, state}
  end

  def handle_in({msg, [opcode: :text]}, state) do
    {:reply, :ok, {:text, msg}, state}
  end

  def terminate(:timeout, state) do
    {:ok, state}
  end
end
