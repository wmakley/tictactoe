defmodule TictactoeLiveWeb.GameLive.Game do
  require Logger
  use TictactoeLiveWeb, :live_view

  import TictactoeLiveWeb.GameComponents

  alias TictactoeLive.Games
  alias TictactoeLive.Games.Player
  alias TictactoeLive.Games.GameState
  alias TictactoeLive.Games.GameServer
  alias TictactoeLiveWeb.GameLive.Form

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_current_date()
     |> set_initial_state(player_name: "", join_token: "")}
  end

  # Needed by layout, normally a plug but when switching to live we need it here
  defp assign_current_date(conn) do
    assign(conn, :current_date, DateTime.utc_now())
  end

  @impl true
  def handle_params(params, _, socket) do
    player_name = Map.get(params, "player_name", "")
    join_token = Map.get(params, "join_token", "")
    form = socket.assigns.form
    form = %{form | player_name: player_name, join_token: join_token}
    {:noreply, socket |> assign(:form, form)}
  end

  defp set_initial_state(socket, player_name: player_name, join_token: join_token)
       when is_binary(player_name) and is_binary(join_token) do
    socket
    |> assign(:form, Form.new())
    |> assign(:join_token, String.trim(join_token))
    # Default player is X, with no name
    |> assign(:player, Player.new())
    # Default game state is empty
    |> assign(:game_state, GameState.new())
    |> assign(:game_pid, nil)
    |> assign(:game_ref, nil)
    |> assign(:chat_message_valid, false)
    |> update_ui_from_game_state
  end

  @impl true
  def handle_event("form_changed", params, socket) do
    # TODO: may not be needed
    form = socket.assigns.form
    player_name = Map.get(params, "player_name", "")
    join_token = Map.get(params, "join_token", "")

    {:noreply,
     socket |> assign(:form, %{form | player_name: player_name, join_token: join_token})}
  end

  def handle_event(
        "join_game",
        %{"player_name" => player_name, "join_token" => join_token} = _params,
        socket
      ) do
    join_token = String.trim(join_token)

    player_name =
      case String.trim(player_name) do
        "" -> "Unnamed Player"
        trimmed -> trimmed
      end

    form = socket.assigns.form

    {:ok, join_token, game_pid} = Games.lookup_or_start_game(join_token)
    game_ref = Process.monitor(game_pid)
    form = %{form | join_token: join_token}

    {:ok, player, game_state} = GameServer.join_game(game_pid, player_name)
    form = %{form | player_name: player.name}

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:player, player)
     |> assign(:game_pid, game_pid)
     |> assign(:game_ref, game_ref)
     |> assign(:game_state, game_state)
     |> update_ui_from_game_state()}
  end

  def handle_event("leave_game", _params, socket) do
    # Logger.debug("#{inspect(self())} GameLive.handle_event(\"leave_game\", #{inspect(_params)})")

    game_ref = socket.assigns.game_ref
    game_pid = socket.assigns.game_pid

    Process.demonitor(game_ref)
    :ok = GameServer.leave_game(game_pid)

    {:noreply,
     socket
     |> assign(:game_pid, nil)
     |> assign(:game_ref, nil)
     |> update_ui_from_game_state()}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, socket)
      when ref == socket.assigns.game_ref do
    # Logger.debug(
    #   "#{inspect(self())} PlayerConn.handle_info({:DOWN, #{inspect(ref)}, :process, #{inspect(object)}, #{inspect(reason)}})"
    # )

    {:noreply,
     socket
     |> assign(:game_pid, nil)
     |> assign(:game_ref, nil)
     |> update_ui_from_game_state()}
  end

  def handle_info({:game_state, game_state}, socket) do
    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> update_ui_from_game_state()}
  end

  defp update_ui_from_game_state(socket) do
    player = socket.assigns.player
    game_state = socket.assigns.game_state

    # TODO: find own player in the game state and copy locally

    socket
    |> assign(:my_turn, player.team == game_state.turn)
    |> assign(:in_game, socket.assigns.game_pid != nil)
  end
end
