defmodule TictactoeLiveWeb.GameLive.Game do
  use TictactoeLiveWeb, :live_view

  import TictactoeLiveWeb.GameComponents

  alias TictactoeLive.Games
  alias TictactoeLive.Games.Player

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    {:noreply, socket |> assign_initial_state(Map.get(params, "player_name", ""))}
  end

  defp assign_initial_state(socket, player_name) do
    socket
    |> assign(:page_title, "Tic Tac Toe")
    |> assign(:in_game, false)
    |> assign(:enough_players, false)
    |> assign(:player, %Player{id: 0, team: "X", name: ""})
    |> assign(:game_state, %Games.Game{})
    |> update_player_name(player_name)
  end

  defp update_player_name(socket, raw_player_name) do
    player = socket.assigns.player

    new_name =
      case String.trim(raw_player_name) do
        "" -> "Unnamed Player"
        trimmed -> trimmed
      end

    socket
    |> assign(:player, Map.put(player, :name, new_name))
  end
end
