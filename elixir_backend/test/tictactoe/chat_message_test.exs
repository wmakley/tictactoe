defmodule Tictactoe.ChatMessageTest do
  use ExUnit.Case, async: true

  alias Tictactoe.ChatMessage

  test "json serialization of player source" do
    msg = %ChatMessage{
      id: 1,
      source: ChatMessage.player_source(1),
      text: "Hello, world!"
    }

    assert Jason.encode!(msg) == ~s({"id":1,"source":{"Player":1},"text":"Hello, world!"})
  end

  test "json serialization of system source" do
    msg = %ChatMessage{
      id: 2,
      source: ChatMessage.system_source(),
      text: "Hello, world 2!"
    }

    assert Jason.encode!(msg) == ~s({"id":2,"source":"System","text":"Hello, world 2!"})
  end
end
