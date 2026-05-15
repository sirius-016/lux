defmodule Lux.Prisms.Twitter.Tweets.Retweet do
  @moduledoc "Prism for creating or removing a retweet."

  use Lux.Prism,
    name: "Retweet",
    description: "Creates or removes a retweet",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        tweet_id: %{type: :string, description: "Tweet to retweet"},
        action: %{type: :string, enum: ["create", "remove"], default: "create"}
      },
      required: ["user_id", "tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, tweet_id: tid, action: "create"}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/retweets", %{json: %{tweet_id: tid}})
  end

  def handler(%{user_id: uid, tweet_id: tid, action: "remove"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/retweets/" <> tid, %{})
  end

  def handler(%{user_id: uid, tweet_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/retweets", %{json: %{tweet_id: tid}})
  end
end
