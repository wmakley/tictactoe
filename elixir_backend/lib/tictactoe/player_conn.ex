defmodule Tictactoe.PlayerConn do
  alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer

  require Logger

  @spec init([{:name, binary} | {:token, binary}, ...]) ::
          {:ok, %{game: pid, player: Tictactoe.Player.t()}}
  def init([name: name, token: token] = options) do
    Logger.debug(fn -> "#{inspect(self())} PlayerConn.init(#{inspect(options)})" end)

    id =
      case String.trim(token) do
        "" ->
          GameRegistry.random_id()

        _ ->
          token
      end

    {:ok, game} = GameRegistry.lookup_or_start_game(GameRegistry, id)
    {:ok, player} = GameServer.add_player(game, name)

    {:ok, %{game: game, player: player}}
  end

  def handle_in({msg, [opcode: :text]}, state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_in(#{inspect(msg)}, #{inspect(state)})"
    end)

    json = Jason.decode!(msg)
    Logger.debug(fn -> "#{inspect(self())} Decoded JSON: #{inspect(json)}" end)

    {:reply, :ok, {:text, Jason.encode!(%{"Error" => "not implemented"})}, state}
  end

  def terminate(reason, %{player: player, game: game} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.terminate(#{inspect(reason)}, #{inspect(state)})"
    end)

    GameServer.disconnect(game, player.id)

    {:ok, state}
  end
end
