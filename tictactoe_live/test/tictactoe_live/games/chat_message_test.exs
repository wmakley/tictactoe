defmodule TictactoeLive.Games.ChatMessageTest do
  use ExUnit.Case, async: true

  alias TictactoeLive.Games.ChatMessage

  describe "ChatMessage" do
    test "system/1 creates a new chat message with the current timestamp and system username" do
      chat_message = dbg(ChatMessage.system("test"))

      assert chat_message == %{
               message: "test",
               timestamp: ~U[2024-01-06 15:16:17.383833Z],
               username: "System"
             }
    end
  end
end
