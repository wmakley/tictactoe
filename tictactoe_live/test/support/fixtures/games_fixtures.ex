defmodule TictactoeLive.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TictactoeLive.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{

      })
      |> TictactoeLive.Games.create_game()

    game
  end
end
