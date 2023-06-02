defmodule Tictactoe.PlayerConn do
  alias Tictactoe.GameRegistry
  alias Tictactoe.GameServer

  require Logger

  @spec init(Keyword.t()) ::
          {:push, {:text, String.t()},
           %{game: pid, player: Tictactoe.Player.t(), game_ref: reference}}
  def init([name: name, token: token] = options) do
    Logger.debug(fn -> "#{inspect(self())} PlayerConn.init(#{inspect(options)})" end)

    id =
      case String.trim(token) do
        "" ->
          GameRegistry.random_id()

        _ ->
          token
      end

    {:ok, game_pid} = GameRegistry.lookup_or_start_game(GameRegistry, id)
    {:ok, player, game_state} = GameServer.join_game(game_pid, name)
    ref = Process.monitor(game_pid)

    {:push, joined_game_response(player, game_state),
     %{game: game_pid, player: player, game_ref: ref}}
  end

  @spec joined_game_response(Tictactoe.Player.t(), Tictactoe.Game.t()) :: {:text, String.t()}
  defp joined_game_response(player, game_state) do
    json = %{
      "JoinedGame" => %{
        "token" => game_state.id,
        "player_id" => player.id,
        "state" => game_state
      }
    }

    {:text, Jason.encode!(json)}
  end

  def handle_in({msg, [opcode: :text]}, %{game: game, player: player} = state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_in(#{inspect(msg)}, #{inspect(state)})"
    end)

    json = Jason.decode!(msg)
    Logger.debug(fn -> "#{inspect(self())} Decoded JSON: #{inspect(json)}" end)

    game_state_or_error =
      case json do
        %{"ChatMsg" => %{"text" => text}} ->
          GameServer.add_chat_message(game, player.id, text)

        _ ->
          {:error, "Unknown message"}
      end

    case game_state_or_error do
      {:ok, game_state} ->
        {:reply, :ok, game_state_response(game_state), state}

      {:error, reason} ->
        {:reply, :ok, error_response(reason), state}
    end
  end

  @spec game_state_response(Tictactoe.Game.t()) :: {:text, String.t()}
  defp game_state_response(game) do
    {:text, Jason.encode!(%{"GameState" => game})}
  end

  @spec error_response(String.t()) :: {:text, String.t()}
  defp error_response(reason) do
    {:text, Jason.encode!(%{"Error" => reason})}
  end

  def handle_info({:game_state, game_state} = message, state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_info(#{inspect(message)})"
    end)

    {:push, game_state_response(game_state), state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason} = message, state) do
    Logger.debug(fn ->
      "#{inspect(self())} PlayerConn.handle_info(#{inspect(message)})"
    end)

    if ref == state.game_ref do
      {:stop, "game exited: #{inspect(reason)}", state}
    else
      {:noreply, state}
    end
  end
end
