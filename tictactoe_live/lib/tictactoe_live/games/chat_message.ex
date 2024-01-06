defmodule TictactoeLive.Games.ChatMessage do
  defstruct [:timestamp, :username, :message]

  def system(message) when is_binary(message) do
    %__MODULE__{
      timestamp: new_timestamp(),
      username: "System",
      message: message
    }
  end

  def player(player_name, player_team, message)
      when is_binary(player_name) and is_binary(player_team) and is_binary(message) do
    %__MODULE__{
      timestamp: new_timestamp(),
      username: "#{player_name} (#{player_team})",
      message: message
    }
  end

  defp new_timestamp() do
    DateTime.now!("Etc/UTC")
  end

  @spec to_json(%__MODULE__{}) :: map
  def to_json(%__MODULE__{} = msg) do
    Map.from_struct(msg)
  end
end

defimpl Jason.Encoder, for: TictactoeLive.Games.ChatMessage do
  def encode(msg, opts) do
    Jason.Encode.map(TictactoeLive.Games.ChatMessage.to_json(msg), opts)
  end
end
