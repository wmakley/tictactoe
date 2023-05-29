defmodule Tictactoe.EchoServer do
  require Logger

  def init(options) do
    Logger.debug("#{inspect(self())} EchoServer.init(#{inspect(options)})")
    {:ok, options}
  end

  def handle_in({msg, [opcode: :text]}, state) do
    Logger.debug("#{inspect(self())} EchoServer.handle_in(#{inspect(msg)}, #{inspect(state)})")
    {:reply, :ok, {:text, msg}, state}
  end

  def terminate(:timeout, state) do
    Logger.debug("#{inspect(self())} EchoServer.terminate(:timeout, #{inspect(state)})")
    {:ok, state}
  end
end
