defmodule TictactoeLiveWeb.GameLiveTest do
  use TictactoeLiveWeb.ConnCase

  import Phoenix.LiveViewTest
  # import TictactoeLive.GamesFixtures

  # @create_attrs %{}
  # @update_attrs %{}
  # @invalid_attrs %{}

  # defp create_game(_) do
  #   game = game_fixture()
  #   %{game: game}
  # end

  # describe "Index" do
  #   setup [:create_game]

  #   test "lists all games", %{conn: conn} do
  #     {:ok, _index_live, html} = live(conn, ~p"/games")

  #     assert html =~ "Listing Games"
  #   end

  #   test "saves new game", %{conn: conn} do
  #     {:ok, index_live, _html} = live(conn, ~p"/games")

  #     assert index_live |> element("a", "New Game") |> render_click() =~
  #              "New Game"

  #     assert_patch(index_live, ~p"/games/new")

  #     assert index_live
  #            |> form("#game-form", game: @invalid_attrs)
  #            |> render_change() =~ "can&#39;t be blank"

  #     assert index_live
  #            |> form("#game-form", game: @create_attrs)
  #            |> render_submit()

  #     assert_patch(index_live, ~p"/games")

  #     html = render(index_live)
  #     assert html =~ "Game created successfully"
  #   end

  #   test "updates game in listing", %{conn: conn, game: game} do
  #     {:ok, index_live, _html} = live(conn, ~p"/games")

  #     assert index_live |> element("#games-#{game.id} a", "Edit") |> render_click() =~
  #              "Edit Game"

  #     assert_patch(index_live, ~p"/games/#{game}/edit")

  #     assert index_live
  #            |> form("#game-form", game: @invalid_attrs)
  #            |> render_change() =~ "can&#39;t be blank"

  #     assert index_live
  #            |> form("#game-form", game: @update_attrs)
  #            |> render_submit()

  #     assert_patch(index_live, ~p"/games")

  #     html = render(index_live)
  #     assert html =~ "Game updated successfully"
  #   end

  #   test "deletes game in listing", %{conn: conn, game: game} do
  #     {:ok, index_live, _html} = live(conn, ~p"/games")

  #     assert index_live |> element("#games-#{game.id} a", "Delete") |> render_click()
  #     refute has_element?(index_live, "#games-#{game.id}")
  #   end
  # end

  describe "Game" do
    # setup [:create_game]

    test "displays new game form", %{conn: conn} do
      {:ok, _show_live, html} = live(conn, ~p"/")

      assert html =~ "Tic Tac Toe"
    end

    # test "updates game within modal", %{conn: conn, game: game} do
    #   {:ok, show_live, _html} = live(conn, ~p"/games/#{game}")

    #   assert show_live |> element("a", "Edit") |> render_click() =~
    #            "Edit Game"

    #   assert_patch(show_live, ~p"/games/#{game}/show/edit")

    #   assert show_live
    #          |> form("#game-form", game: @invalid_attrs)
    #          |> render_change() =~ "can&#39;t be blank"

    #   assert show_live
    #          |> form("#game-form", game: @update_attrs)
    #          |> render_submit()

    #   assert_patch(show_live, ~p"/games/#{game}")

    #   html = render(show_live)
    #   assert html =~ "Game updated successfully"
    # end
  end
end
