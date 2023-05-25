defmodule Tictactoe.ChatMessage do
  defstruct [:id, :source, :text]

  @spec player_source(integer) :: {:player, integer}
  def player_source(id) when is_integer(id) do
    {:player, id}
  end

  @spec system_source() :: :system
  def system_source do
    :system
  end

  def json_representation(%__MODULE__{} = msg) do
    source =
      case msg.source do
        {:player, id} ->
          %{"Player" => id}

        :system ->
          "System"
      end

    %{
      id: msg.id,
      source: source,
      text: msg.text
    }
  end
end

defimpl Jason.Encoder, for: Tictactoe.ChatMessage do
  alias Tictactoe.ChatMessage

  def encode(msg, opts) do
    Jason.Encode.map(ChatMessage.json_representation(msg), opts)
  end
end
