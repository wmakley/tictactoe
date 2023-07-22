defmodule TictactoeLive.Games.ChatMessage do
  defstruct [:id, :source, :text]

  @spec new(integer, :system, String.t()) :: %__MODULE__{
          id: integer,
          source: :system,
          text: String.t()
        }
  def new(id, :system, text) when is_integer(id) and is_binary(text) do
    %__MODULE__{id: id, source: :system, text: text}
  end

  @spec new(integer, {:player, integer}, String.t()) :: %__MODULE__{
          id: integer,
          source: {:player, integer},
          text: String.t()
        }
  def new(id, {:player, player_id}, text)
      when is_integer(id) and is_integer(player_id) and is_binary(text) do
    %__MODULE__{id: id, source: {:player, player_id}, text: text}
  end

  @spec player_source(integer) :: {:player, integer}
  def player_source(id) when is_integer(id) do
    {:player, id}
  end

  @spec system_source() :: :system
  def system_source do
    :system
  end

  @spec to_json(%__MODULE__{}) :: map
  def to_json(%__MODULE__{} = msg) do
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

defimpl Jason.Encoder, for: TictactoeLive.Games.ChatMessage do
  def encode(msg, opts) do
    Jason.Encode.map(TictactoeLive.Games.ChatMessage.to_json(msg), opts)
  end
end
