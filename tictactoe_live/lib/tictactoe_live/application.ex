defmodule TictactoeLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TictactoeLiveWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: TictactoeLive.PubSub},
      # Game registry
      {Registry, keys: :unique, name: TictactoeLive.Games.GameRegistry},
      {DynamicSupervisor, name: TictactoeLive.Games.GameSupervisor},
      # Start Finch
      {Finch, name: TictactoeLive.Finch},
      # Start the Endpoint (http/https)
      TictactoeLiveWeb.Endpoint
      # Start a worker by calling: TictactoeLive.Worker.start_link(arg)
      # {TictactoeLive.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TictactoeLive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TictactoeLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
