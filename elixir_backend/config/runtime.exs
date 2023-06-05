case Mix.env() do
  :dev ->
    Logger.configure(level: :debug)

  :test ->
    Logger.configure(level: :debug)

  :prod ->
    Logger.configure(level: :info)
end
