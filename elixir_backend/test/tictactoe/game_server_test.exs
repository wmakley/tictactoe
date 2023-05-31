defmodule Tictactoe.GameServerTest do
  use ExUnit.Case, async: true

  alias Tictactoe.Game
  alias Tictactoe.GameServer
  alias Tictactoe.Player
  alias Tictactoe.ChatMessage

  setup do
    game = start_link_supervised!({GameServer, random_int_id()})
    {:ok, %{game: game}}
  end

  defp random_int_id() do
    Integer.to_string(:rand.uniform(1_000_000))
  end

  test "can start and connect to game, send a chat message, and get it back", %{game: pid} do
    {:ok, player, %Game{} = game_state} = GameServer.join_game(pid, "Player 1")
    assert player == %Player{id: 1, name: "Player 1", team: "X"}

    expected_first_message = %ChatMessage{
      id: 1,
      text: "Player 1 (X) has joined the game",
      source: :system
    }

    assert game_state.chat == [
             expected_first_message
           ]

    GameServer.add_chat_message(pid, player.id, "Hello")

    receive do
      {:game_state, game_state} ->
        assert game_state.chat == [
                 expected_first_message,
                 %ChatMessage{id: 2, source: {:player, 1}, text: "Hello"}
               ]

      other ->
        flunk("Unexpected message: #{inspect(other)}")
    end
  end
end
