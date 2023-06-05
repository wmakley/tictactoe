import Config

port =
  System.get_env("PORT", "3000")
  |> String.to_integer()

config :tictactoe, :port, port

case Mix.env() do
  :dev ->
    Logger.configure(level: :debug)

  :test ->
    Logger.configure(level: :debug)

  :prod ->
    Logger.configure(level: :info)
end
