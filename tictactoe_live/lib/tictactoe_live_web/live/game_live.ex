defmodule TictactoeLiveWeb.GameLive do
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
    connect_params =
      dbg(
        case get_connect_params(socket) do
          nil -> %{}
          params -> params
        end
      )

    player_name = Map.get(connect_params, "player_name", "")
    join_token = Map.get(connect_params, "join_token", "")

    {:ok,
     socket
     |> assign_current_date()
     |> set_initial_state(player_name: player_name, join_token: join_token)}
  end

  # Needed by layout, normally a plug but when switching to live we need it here
  defp assign_current_date(conn) do
    assign(conn, :current_date, DateTime.utc_now())
  end

  @impl true
  def handle_params(%{"token" => join_token}, _, socket) do
    Logger.debug(
      "#{inspect(self())} GameLive.handle_params(): immediately joining game: #{inspect(join_token)}"
    )

    form = socket.assigns.form
    form = %{form | join_token: join_token}

    {:noreply,
     socket
     |> assign(:form, form)
     |> join_game(form.player_name, join_token)}
  end

  def handle_params(_params, _, socket) do
    {:noreply, socket}
  end

  defp set_initial_state(socket, player_name: player_name, join_token: join_token)
       when is_binary(player_name) and is_binary(join_token) do
    socket
    |> assign(:form, %Form{
      player_name: String.trim(player_name),
      join_token: String.trim(join_token)
    })
    |> assign(:chat_message, "")
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
    # TODO: this handler may not be needed
    form = socket.assigns.form
    player_name = Map.get(params, "player_name", "")
    join_token = Map.get(params, "join_token", "")

    # update form values
    form = %{form | player_name: player_name, join_token: join_token}

    {:noreply, socket |> assign(:form, form)}
  end

  def handle_event("update_player_name", %{"value" => name} = params, socket) do
    name = name |> String.trim() |> String.slice(0..32)
    player = socket.assigns.player

    name_changed = name != player.name

    if name_changed do
      form = socket.assigns.form
      form = %{form | player_name: name}

      {:ok, normalized_name, game_state} =
        if in_game?(socket) do
          # Allow the game server to make changes it deems necessary.
          GameServer.update_player_name(socket.assigns.game_pid, name)
        else
          # No additional normalization if not in-game.
          {:ok, name, socket.assigns.game_state}
        end

      player = %{player | name: normalized_name}

      {:noreply,
       socket
       |> assign(:form, form)
       |> assign(:game_state, game_state)
       |> assign(:player, player)
       |> update_ui_from_game_state()
       |> push_event("player_name_changed", %{value: name})}
    else
      Logger.debug(
        "#{inspect(self())} GameLive.handle_event(\"update_player_name\", #{inspect(params)}): name not actually changed"
      )

      {:noreply, socket}
    end
  end

  def handle_event(
        "join_game",
        %{"player_name" => player_name, "join_token" => join_token} = _params,
        socket
      ) do
    {:noreply, socket |> join_game(player_name, join_token)}
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

  def handle_event("validate_chat_message", %{"msg" => msg}, socket) do
    {:noreply,
     socket
     |> assign(:chat_message, msg)
     |> assign(:chat_message_valid, String.trim(msg) != "")}
  end

  def handle_event("send_chat_message", %{"msg" => msg}, socket) do
    {:ok, game_state} = GameServer.add_chat_message(socket.assigns.game_pid, String.trim(msg))

    {:noreply,
     socket
     |> assign(:chat_message, "")
     |> assign(:chat_message_valid, false)
     |> assign(:game_state, game_state)
     |> update_ui_from_game_state()}
  end

  def handle_event("take_turn", %{"square" => square}, socket) do
    index = String.to_integer(square)
    {:ok, game_state} = GameServer.take_turn(socket.assigns.game_pid, index)

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> update_ui_from_game_state()}
  end

  def handle_event("rematch", _params, socket) do
    {:ok, game_state} = GameServer.rematch(socket.assigns.game_pid)

    {:noreply,
     socket
     |> assign(:game_state, game_state)
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

  defp in_game?(socket) do
    socket.assigns.in_game
  end

  defp join_game(socket, player_name, join_token) do
    join_token = String.trim(join_token)
    player_name = String.trim(player_name)

    form = socket.assigns.form

    {:ok, join_token, game_pid} = Games.lookup_or_start_game(join_token)
    game_ref = Process.monitor(game_pid)
    form = %{form | join_token: join_token}

    {:ok, player, game_state} = GameServer.join_game(game_pid, player_name)
    form = %{form | player_name: player.name}

    socket
    |> assign(:form, form)
    |> assign(:player, player)
    |> assign(:game_pid, game_pid)
    |> assign(:game_ref, game_ref)
    |> assign(:game_state, game_state)
    |> update_ui_from_game_state()
  end

  defp update_ui_from_game_state(socket) do
    Logger.debug("#{inspect(self())} update_ui_from_game_state()")

    player = socket.assigns.player
    game_state = socket.assigns.game_state

    # Game server tracks wins and losses in the player record
    my_turn = player.team == game_state.turn
    # Logger.debug("#{player.name}: my_turn: #{inspect(my_turn)}")

    in_game = socket.assigns.game_pid != nil
    # Logger.debug("#{player.name}: in_game: #{inspect(in_game)}")

    # if in_game do
    #   {:ok, player} = GameState.find_player(game_state, player.id)
    #   Logger.debug("player: #{inspect(me)}")
    # end

    socket
    |> assign(:my_turn, my_turn)
    |> assign(:in_game, in_game)
  end
end