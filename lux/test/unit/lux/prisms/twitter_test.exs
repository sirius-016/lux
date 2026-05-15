defmodule Lux.Prisms.TwitterTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Tweets.{CreateTweet, DeleteTweet, CreateThread, Retweet, LikeTweet, Bookmark, QuoteTweet}
  alias Lux.Prisms.Twitter.Users.{FollowUser, BlockUser, MuteUser}

  import Mox

  setup :verify_on_exit!

  describe "CreateTweet" do
    test "creates a simple tweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/tweets"
        Req.Test.json(conn, 201, %{"data" => %{"id" => "1", "text" => "Hello"}})
      end)

      assert {:ok, _} = CreateTweet.handler(%{text: "Hello"}, nil)
    end

    test "creates tweet with reply settings" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 201, %{"data" => %{"id" => "2", "text" => "Reply"}})
      end)

      assert {:ok, _} = CreateTweet.handler(%{text: "Reply", reply: %{in_reply_to_tweet_id: "1"}}, nil)
    end
  end

  describe "DeleteTweet" do
    test "deletes a tweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/tweets/123"
        Req.Test.json(conn, 200, %{"data" => %{"deleted" => true}})
      end)

      assert {:ok, _} = DeleteTweet.handler(%{tweet_id: "123"}, nil)
    end
  end

  describe "CreateThread" do
    test "creates a thread of tweets" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 201, %{"data" => %{"id" => "1"}})
      end)

      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 201, %{"data" => %{"id" => "2"}})
      end)

      assert {:ok, %{tweets: tweets}} = CreateThread.handler(%{tweets: ["First", "Second"]}, nil)
      assert length(tweets) == 2
    end
  end

  describe "Retweet" do
    test "creates retweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/retweets"
        Req.Test.json(conn, 200, %{"data" => %{"retweeted" => true}})
      end)

      assert {:ok, _} = Retweet.handler(%{user_id: "me", tweet_id: "123"}, nil)
    end

    test "removes retweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path =~ "/retweets/123"
        Req.Test.json(conn, 200, %{"data" => %{}})
      end)

      assert {:ok, _} = Retweet.handler(%{user_id: "me", tweet_id: "123", action: "remove"}, nil)
    end
  end

  describe "LikeTweet" do
    test "likes a tweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 200, %{"data" => %{"liked" => true}})
      end)

      assert {:ok, _} = LikeTweet.handler(%{user_id: "me", tweet_id: "123"}, nil)
    end

    test "unlikes a tweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "DELETE"
        Req.Test.json(conn, 200, %{"data" => %{}})
      end)

      assert {:ok, _} = LikeTweet.handler(%{user_id: "me", tweet_id: "123", action: "remove"}, nil)
    end
  end

  describe "Bookmark" do
    test "creates bookmark" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 200, %{"data" => %{"bookmarked" => true}})
      end)

      assert {:ok, _} = Bookmark.handler(%{user_id: "me", tweet_id: "123"}, nil)
    end
  end

  describe "QuoteTweet" do
    test "creates quote tweet" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 201, %{"data" => %{"id" => "1"}})
      end)

      assert {:ok, _} = QuoteTweet.handler(%{text: "Check this", quote_tweet_id: "99"}, nil)
    end
  end

  describe "FollowUser" do
    test "follows user" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 200, %{"data" => %{"following" => true}})
      end)

      assert {:ok, _} = FollowUser.handler(%{user_id: "me", target_user_id: "them"}, nil)
    end

    test "unfollows user" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "DELETE"
        Req.Test.json(conn, 200, %{"data" => %{}})
      end)

      assert {:ok, _} = FollowUser.handler(%{user_id: "me", target_user_id: "them", action: "unfollow"}, nil)
    end
  end

  describe "BlockUser" do
    test "blocks user" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 200, %{"data" => %{"blocking" => true}})
      end)

      assert {:ok, _} = BlockUser.handler(%{user_id: "me", target_user_id: "them"}, nil)
    end
  end

  describe "MuteUser" do
    test "mutes user" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, 200, %{"data" => %{"muting" => true}})
      end)

      assert {:ok, _} = MuteUser.handler(%{user_id: "me", target_user_id: "them"}, nil)
    end
  end
end
