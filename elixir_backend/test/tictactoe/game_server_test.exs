defmodule Tictactoe.GameServerTest do
  use ExUnit.Case, async: true

  alias Tictactoe.Game
  alias Tictactoe.GameServer
  alias Tictactoe.Player
  alias Tictactoe.ChatMessage
  alias Tictactoe.FakePlayer

  setup do
    game_id = random_int_id()
    game = start_link_supervised!({GameServer, id: game_id})
    {:ok, %{game: game, game_id: game_id}}
  end

  defp random_int_id() do
    Integer.to_string(:rand.uniform(1_000_000))
  end

  test "dump_state", %{game: pid} do
    state = GameServer.dump_state(pid)
    assert is_map(state)
  end

  test "can start and connect to game, send a chat message, and get it back", %{game: pid} do
    # uses the test process as the player
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

    GameServer.add_chat_message(pid, "Hello")

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

  test "player is removed from game if they crash", %{game: game} do
    {:ok, player} = start_supervised(FakePlayer)
    refute FakePlayer.joined?(player)
    {:ok, _player, game_state} = FakePlayer.join_game(player, game, player_name: "Player 1")
    assert FakePlayer.joined?(player)

    assert length(game_state.players) == 1

    # crash the player
    Process.exit(player, :kill)

    # Cannot guarantee when the server will get the message
    Process.sleep(100)

    game_state = GameServer.dump_state(game)
    assert Enum.empty?(game_state.connections)
    assert length(game_state.game.players) == 0
  end
end
