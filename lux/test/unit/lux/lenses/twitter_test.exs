defmodule Lux.Lenses.TwitterTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.{GetTweet, GetUser, SearchTweets, GetTimeline, GetMentions, GetFollowers, GetFollowing}

  describe "GetTweet" do
    test "formats tweet response correctly" do
      response = %{"data" => %{
        "id" => "123",
        "text" => "Hello world",
        "author_id" => "456",
        "created_at" => "2024-01-01T00:00:00.000Z",
        "public_metrics" => %{"like_count" => 10, "retweet_count" => 5}
      }}
      assert {:ok, tweet} = GetTweet.after_focus(response)
      assert tweet.id == "123"
      assert tweet.text == "Hello world"
      assert tweet.public_metrics["like_count"] == 10
    end

    test "handles error response" do
      assert {:error, _} = GetTweet.after_focus(%{"errors" => [%{"message" => "Not found"}]})
    end
  end

  describe "GetUser" do
    test "before_focus sets URL for username lookup" do
      params = %{username: "testuser"}
      updated = GetUser.before_focus(params)
      assert updated[:url] =~ "/users/by/username/testuser"
      refute Map.has_key?(updated, :username)
    end

    test "before_focus sets URL for user_id lookup" do
      params = %{user_id: "12345"}
      updated = GetUser.before_focus(params)
      assert updated[:url] =~ "/users/12345"
      refute Map.has_key?(updated, :user_id)
    end

    test "formats user response" do
      response = %{"data" => %{
        "id" => "123", "name" => "Test", "username" => "testuser",
        "description" => "Bio", "verified" => true, "public_metrics" => %{"followers_count" => 100}
      }}
      assert {:ok, user} = GetUser.after_focus(response)
      assert user.username == "testuser"
      assert user.verified == true
    end
  end

  describe "SearchTweets" do
    test "formats search results" do
      response = %{
        "data" => [%{"id" => "1", "text" => "Tweet 1", "author_id" => "a", "created_at" => "2024-01-01T00:00:00Z", "public_metrics" => %{}}],
        "meta" => %{"result_count" => 1}
      }
      assert {:ok, result} = SearchTweets.after_focus(response)
      assert length(result.tweets) == 1
      assert result.meta["result_count"] == 1
    end
  end

  describe "GetTimeline" do
    test "before_focus replaces user_id in URL" do
      params = %{user_id: "999", max_results: 20}
      updated = GetTimeline.before_focus(params)
      assert updated[:url] =~ "/users/999/tweets"
      assert updated[:max_results] == 20
    end
  end

  describe "GetMentions" do
    test "before_focus replaces user_id in URL" do
      params = %{user_id: "999"}
      updated = GetMentions.before_focus(params)
      assert updated[:url] =~ "/users/999/mentions"
    end
  end

  describe "GetFollowers" do
    test "before_focus replaces user_id in URL" do
      params = %{user_id: "999"}
      updated = GetFollowers.before_focus(params)
      assert updated[:url] =~ "/users/999/followers"
    end
  end

  describe "GetFollowing" do
    test "before_focus replaces user_id in URL" do
      params = %{user_id: "999"}
      updated = GetFollowing.before_focus(params)
      assert updated[:url] =~ "/users/999/following"
    end
  end
end
