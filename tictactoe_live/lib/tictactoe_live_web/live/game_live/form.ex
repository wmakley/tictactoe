defmodule TictactoeLiveWeb.GameLive.Form do
  @moduledoc """
  Struct to hold the state of the "join game" form.
  """

  defstruct player_name: "", join_token: ""

  def new() do
    %__MODULE__{}
  end
end
