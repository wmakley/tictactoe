import Config

port =
  System.get_env("PORT", "3000")
  |> String.to_integer()

config :tictactoe, :port, port

log_level = System.get_env("LOG_LEVEL", nil)

if log_level do
  Logger.configure(level: String.to_atom(log_level))
else
  case Mix.env() do
    :dev ->
      Logger.configure(level: :info)

    :test ->
      Logger.configure(level: :warning)

    :prod ->
      Logger.configure(level: :warning)
  end
end
