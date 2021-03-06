defmodule Brave.GamesTest do
  use Brave.DataCase

  alias Brave.Games
  alias Brave.Users

  describe "games" do
    alias Brave.Games.Game

    def fixture(:p1) do
      {:ok, user} = Users.create_user(%{"username" => "p1", "password" => "password"})
      user
    end

    def fixture(:p2) do
      {:ok, user} = Users.create_user(%{"username" => "p2", "password" => "password"})
      user
    end

    def fixture(:p3) do
      {:ok, user} = Users.create_user(%{"username" => "p3", "password" => "password"})
      user
    end

    def game_fixture(p1, p2, attrs \\ %{}) do
      {:ok, game} =
        attrs
        |> Enum.into(%{p1_uuid: p1.uuid, p2_uuid: p2.uuid, p1_name: p1.username, p2_name: p2.username})
        |> Games.create_game()

      game
    end

    test "list_games/1 and list_completed_games/1 return all games in progress and completed respectively" do
      p1 = fixture(:p1)
      p2 = fixture(:p2)
      p3 = fixture(:p3)

      game = game_fixture(p1,p2)
      game2 = game_fixture(p1, p2, %{completed?: true})

      game3 = game_fixture(p3, p2)
      game4 = game_fixture(p1, p3, %{completed?: true})

      assert Games.list_games(%{"user" => p1.uuid}) == {:ok, [game]}
      assert Games.list_games(%{"user" => p2.uuid}) == {:ok, [game, game3]}
      assert Games.list_games(%{"user" => p2.uuid, "opponent" => p3.username}) == {:ok, [game3]}
      assert Games.list_games(%{"user" => p1.uuid, "opponent" => p3.username}) == {:ok, []}

      assert Games.list_completed_games(%{"user" => p1.uuid}) == {:ok, [game2, game4]}
      assert Games.list_completed_games(%{"user" => p3.uuid, "opponent" => p1.username}) == {:ok, [game4]}
      assert Games.list_completed_games(%{"user" => p2.uuid, "opponent" => p3.username}) == {:ok, []}
    end

    test "list_games/1 and list_completed_games/1 return errors with invalid inputs" do
      assert %{errors: %{"user" => ["required field"]}} = Games.list_games(%{})
      assert %{errors: %{"user" => ["required field"]}} = Games.list_completed_games(%{})
    end


    test "create_game/1 with valid data creates a game" do
      p1 = fixture(:p1)
      p2 = fixture(:p2)
      game_params = %{p1_uuid: p1.uuid, p2_uuid: p2.uuid, p1_name: p1.username, p2_name: p2.username}
      assert {:ok, %Game{} = game} = Games.create_game(game_params)
      assert game.completed? == false
      assert game.on_hold == []
      assert game.p1_card == nil
      assert game.p1_cards == [0,1,2,3,4,5,6,7]
      assert game.p1_general? == false
      assert game.p1_spy? == false
      assert game.p1_name == p1.username
      assert game.p1_points == 0
      assert game.p1_uuid == p1.uuid
      assert game.p1_winnings == []
      assert game.p2_card == nil
      assert game.p2_cards == [0,1,2,3,4,5,6,7]
      assert game.p2_general? == false
      assert game.p2_spy? == false
      assert game.p2_name == p2.username
      assert game.p2_points == 0
      assert game.p2_uuid == p2.uuid
      assert game.p2_winnings == []
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_game(%{})
    end

    test "update_game/1 returns updated game" do
      p1 = fixture(:p1)
      p2 = fixture(:p2)

      game1 = game_fixture(p1, p2, %{})

      Games.update_game(%{"id" => game1.game_id, "user" => p1.uuid, "card" => "1"})
      assert {:ok, %Game{
        p1_cards: [0,2,3,4,5,6,7],
        p2_cards: [0,1,2,3,4,5,6],
        p1_card: nil,
        p2_card: nil,
        p1_points: 10,
        p2_points: 0,
        completed?: true,
      }} = Games.update_game(%{"id" => game1.game_id, "user" => p2.uuid, "card" => "7"})

      assert %{errors: %{"id" => ["game is over"]}} = Games.update_game(%{"id" => game1.game_id, "user" => p1.uuid, "card" => "1"})

      game2 = game_fixture(p1, p2, %{})
      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "3"})
      assert {:ok, %Game{
        p1_points: 0,
        p2_points: 1,
        p1_winnings: [],
        p2_winnings: [[3,2]],
        p1_spy?: false,
        p2_spy?: true
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "2"})

      assert %{errors: %{"card" => ["invalid card:3"]}} = Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "3"})
      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "4"})
      assert %{errors: %{"card" => ["not your turn"]}} = Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "5"})
      assert {:ok, %Game{
        p1_points: 0,
        p2_points: 1,
        p1_winnings: [],
        p2_winnings: [[3,2]],
        p1_spy?: false,
        p2_spy?: false,
        on_hold: [[4,4]]
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "4"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "7"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 1,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[3,2]],
        p1_general?: false,
        p2_general?: true,
        on_hold: []
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "6"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "5"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 2,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[5,5], [3,2]],
        p1_general?: false,
        p2_general?: false,
        on_hold: []
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "5"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "0"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 2,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[5,5], [3,2]],
        on_hold: [[0,7]]
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "7"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "2"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 2,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[5,5], [3,2]],
        on_hold: [[2,0],[0,7]]
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "0"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "1"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 2,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[5,5], [3,2]],
        on_hold: [[1,1],[2,0],[0,7]]
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "1"})

      Games.update_game(%{"id" => game2.game_id, "user" => p1.uuid, "card" => "6"})
      assert {:ok, %Game{
        p1_points: 3,
        p2_points: 6,
        p1_winnings: [[7,6], [4,4]],
        p2_winnings: [[6,3],[1,1],[2,0],[0,7],[5,5], [3,2]],
        on_hold: [],
        completed?: true
      }} = Games.update_game(%{"id" => game2.game_id, "user" => p2.uuid, "card" => "3"})

      game3 = game_fixture(p1, p2, %{})
      assert %{errors: %{"card" => ["invalid card:8"]}} = Games.update_game(%{"id" => game3.game_id, "user" => p2.uuid, "card" => "8"})
      Games.update_game(%{"id" => game3.game_id, "user" => p1.uuid, "card" => "4"})
      Games.update_game(%{"id" => game3.game_id, "user" => p2.uuid, "card" => "7"})
      assert {:ok, %Game{
        p1_points: 0,
        p2_points: 1,
        p1_winnings: [],
        p2_winnings: [[4,7]],
        completed?: true
      }}

      Games.update_game(%{"id" => game3.game_id, "user" => p1.uuid, "card" => "7"})
      assert {:ok, %Game{
        p1_points: 0,
        p2_points: 10,
        p1_winnings: [],
        p2_winnings: [[7,1],[4,7]],
        completed?: true
      }} = Games.update_game(%{"id" => game3.game_id, "user" => p2.uuid, "card" => "1"})
    end

    test "update_game/1 ends the game if cards run out" do
      p1 = fixture(:p1)
      p2 = fixture(:p2)

      game = game_fixture(p1, p2, %{})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "0"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "0"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "1"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "1"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "2"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "2"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "3"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "3"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "4"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "4"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "5"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "5"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "6"})
      Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "6"})
      Games.update_game(%{"id" => game.game_id, "user" => p1.uuid, "card" => "7"})
      assert {:ok, %Game{
        p1_points: 0,
        p2_points: 0,
        p1_winnings: [],
        p2_winnings: [],
        on_hold: [[7,7],[6,6],[5,5],[4,4],[3,3],[2,2],[1,1],[0,0]],
        completed?: true
      }} = Games.update_game(%{"id" => game.game_id, "user" => p2.uuid, "card" => "7"})

    end

    test "update_game/1 with invalid input returns error" do
      assert %{errors: %{"card" => ["required field"]}} = Games.update_game(%{"id" => "game uuid", "user" => "user uuid"})
      assert %{errors: %{"user" => ["required field"]}} = Games.update_game(%{"id" => "game uuid", "card" => 1})
      assert %{errors: %{"id" => ["required field"]}} = Games.update_game(%{"user" => "user uuid", "card" => 1})
      assert %{errors: %{"id" => ["required field"], "card" => ["required field"]}} = Games.update_game(%{"user" => "user id"})
      assert %{errors: %{"id" => ["required field"],"user" => ["required field"], "card" => ["required field"]}} = Games.update_game(%{})
    end

    test "get_game/1 returns the game when there is valid input" do
      p1 = fixture(:p1)
      p2 = fixture(:p2)
      game = game_fixture(p1, p2, %{})

      assert Games.get_game(%{"id" => game.game_id}) == {:ok, game}
    end

    test "get_game/1 returns error with invalid input" do
      assert %{errors: %{"id" => ["required field"]}} = Games.get_game(%{})
      assert %{errors: %{"id" => ["invalid game id"]}} = Games.get_game(%{"id" => "invalid game uuid"})
    end
  end
end
