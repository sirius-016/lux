defmodule Lux.Prisms.Twitter.Tweets.LikeTweet do
  @moduledoc "Prism for liking or unliking a tweet."

  use Lux.Prism,
    name: "Like Tweet",
    description: "Likes or unlikes a tweet",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        tweet_id: %{type: :string, description: "Tweet to like"},
        action: %{type: :string, enum: ["create", "remove"], default: "create"}
      },
      required: ["user_id", "tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, tweet_id: tid, action: "remove"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/likes/" <> tid, %{})
  end

  def handler(%{user_id: uid, tweet_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/likes", %{json: %{tweet_id: tid}})
  end
end
