import Config

port =
  System.get_env("PORT", "3000")
  |> String.to_integer()

config :tictactoe, :port, port

config :tictactoe,
       :frontend_url,
       System.get_env("FRONTEND_URL", "http://localhost:5173")

log_level = System.get_env("LOG_LEVEL", nil)

if log_level do
  Logger.configure(level: String.to_atom(log_level))
else
  case config_env() do
    :dev ->
      Logger.configure(level: :debug)

    :test ->
      Logger.configure(level: :info)

    _ ->
      nil
      # Logger.configure(level: :info)
  end
end
