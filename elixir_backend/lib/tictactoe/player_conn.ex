defmodule Tictactoe.PlayerConn do
  alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer

  require Logger

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
    {:ok, player, game_state} = GameServer.add_player(game, name)

    # TODO: Game crash should kill connection.
    # TODO: Connection crash should remove the player from game.

    response = %{
      "JoinedGame" => %{
        "token" => id,
        "player_id" => player.id,
        "state" => game_state
      }
    }

    {:push, {:text, Jason.encode!(response)}, %{game: game, player: player}}
  end

  def handle_in({msg, [opcode: :text]}, %{game: game, player: player} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_in(#{inspect(msg)}, #{inspect(state)})"
    end)

    json = Jason.decode!(msg)
    Logger.debug(fn -> "#{inspect(self())} Decoded JSON: #{inspect(json)}" end)

    state_or_error =
      case json do
        %{"ChatMsg" => %{"text" => text}} ->
          GameServer.add_chat_message(game, player.id, text)

          # TODO
      end

    case state_or_error do
      {:ok, game} ->
        {:reply, :ok, {:text, Jason.encode!(%{"GameState" => game})}, state}

      {:error, reason} ->
        {:reply, :ok, {:text, Jason.encode!(%{"Error" => reason})}, state}
    end
  end

  def handle_info({:game_state, _}, state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_info(:game_state, #{inspect(state)})"
    end)

    {:noreply, state}
  end

  @spec terminate(any, %{
          :game => pid,
          :player => atom | %{:id => integer, optional(any) => any},
          optional(any) => any
        }) :: {:ok, %{:game => pid, :player => atom | map, optional(any) => any}}
  def terminate(reason, %{player: player, game: game} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.terminate(#{inspect(reason)}, #{inspect(state)})"
    end)

    GameServer.disconnect(game, player.id)

    {:ok, state}
  end
end
