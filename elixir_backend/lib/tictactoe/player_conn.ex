defmodule Tictactoe.PlayerConn do
  @moduledoc """
  A player connection process, which manages a single player's connection to a
  game via websocket. Implements the WebSock behaviour.

  Monitors the game server process. If the game server process terminates,
  the player connection also terminates.
  """
  # alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer
  # alias Tictactoe.GameSupervisor

  require Logger

  @spec init(Keyword.t()) ::
          {:push, {:text, String.t()},
           %{game: pid, game_ref: reference, player: Tictactoe.Player.t()}}
  def init([name: name, token: token] = options) when is_binary(name) and is_binary(token) do
    Logger.info("#{inspect(self())} PlayerConn.init(#{inspect(options)})")

    {:ok, id, game_pid} = Tictactoe.lookup_or_start_game(token)

    # From now on, we crash when the game crashes:
    game_ref = Process.monitor(game_pid)
    {:ok, player, game_state} = GameServer.join_game(game_pid, name)

    {:push, joined_game_response(id, player, game_state),
     %{game: game_pid, game_ref: game_ref, player: player}}
  end

  def handle_in({msg, [opcode: :text]}, %{game: game} = state) do
    Logger.debug("#{inspect(self())} PlayerConn.handle_in(#{inspect(msg)})")

    json = Jason.decode!(msg)
    # Logger.debug(fn -> "#{inspect(self())} Decoded JSON: #{inspect(json)}" end)

    game_state_or_error =
      case json do
        %{"ChatMsg" => %{"text" => text}} ->
          GameServer.add_chat_message(game, text)

        %{"ChangeName" => %{"new_name" => new_name}} ->
          GameServer.update_player_name(game, new_name)

        %{"Move" => %{"space" => space}} ->
          GameServer.take_turn(game, space)

        "Rematch" ->
          GameServer.rematch(game)

        other ->
          {:error, "Unknown message: #{inspect(other)}}"}
      end

    case game_state_or_error do
      {:ok, _game_state} ->
        # Game will broadcast the new game state to all players.
        {:ok, state}

      {:error, reason} ->
        {:reply, :ok, error_response(reason), state}
    end
  end

  def handle_info({:game_state, game_state}, state) do
    # Logger.debug(fn ->
    #   "#{inspect(self())} PlayerConn.handle_info(#{inspect(message)})"
    # end)

    {:push, game_state_response(game_state), state}
  end

  def handle_info({:DOWN, ref, :process, object, reason}, %{game_ref: game_ref} = state)
      when ref == game_ref do
    Logger.debug(
      "#{inspect(self())} PlayerConn.handle_info({:DOWN, #{inspect(ref)}, :process, #{inspect(object)}, #{inspect(reason)}})"
    )

    {:stop, reason, state}
  end

  @spec joined_game_response(String.t(), Tictactoe.Player.t(), Tictactoe.Game.t()) ::
          {:text, String.t()}
  defp joined_game_response(id, player, game_state) do
    json = %{
      "JoinedGame" => %{
        "token" => id,
        "player_id" => player.id,
        "state" => game_state
      }
    }

    {:text, Jason.encode!(json)}
  end

  @spec game_state_response(Tictactoe.Game.t()) :: {:text, String.t()}
  defp game_state_response(game) do
    {:text, Jason.encode!(%{"GameState" => game})}
  end

  @spec error_response(String.t()) :: {:text, String.t()}
  defp error_response(reason) do
    {:text, Jason.encode!(%{"Error" => reason})}
  end
end
