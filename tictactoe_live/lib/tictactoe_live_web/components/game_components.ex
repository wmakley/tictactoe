defmodule TictactoeLiveWeb.GameComponents do
  require Logger
  use Phoenix.Component

  attr :value, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def square(assigns) do
    Logger.debug("square(#{inspect(assigns)})")

    ~H"""
    <div class={["game-square", @disabled && "disabled"]} {@rest}>
      <%= @value %>
    </div>
    """
  end
end
