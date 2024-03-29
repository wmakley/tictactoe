defmodule TictactoeLiveWeb.GameComponents do
  require Logger
  use Phoenix.Component

  attr :value, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def square(assigns) do
    ~H"""
    <div
      class={[
        "game-square",
        @disabled && "disabled",
        !@disabled && "enabled",
        String.downcase(@value)
      ]}
      {@rest}
    >
      <%= @value %>
    </div>
    """
  end

  attr :value, :string

  def join_game_error(assigns) do
    ~H"""
    <%= if @value do %>
      <div class="join-error">
        <p>Join error: <%= @value %></p>
      </div>
    <% end %>
    """
  end
end
