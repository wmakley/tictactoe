defmodule TictactoeLiveWeb.Router do
  use TictactoeLiveWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TictactoeLiveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_current_date
  end

  defp assign_current_date(conn, _opts) do
    assign(conn, :current_date, DateTime.utc_now())
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TictactoeLiveWeb do
    pipe_through :browser

    live "/", GameLive, :home
    live "/game/join", GameLive, :game
    live "/game/:token", GameLive, :game
  end

  # Other scopes may use custom stacks.
  # scope "/api", TictactoeLiveWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tictactoe_live, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TictactoeLiveWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
