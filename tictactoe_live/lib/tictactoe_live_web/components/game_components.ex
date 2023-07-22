defmodule TictactoeLiveWeb.GameComponents do
  use Phoenix.Component

  attr :index, :integer
  attr :value, :string, default: ""
  attr :disabled, :boolean, default: false

  def square(assigns) do
    ~H"""
    <div class={["game-square", @disabled && "disabled"]}>
      <%= @value %>
    </div>
    """
  end
end
