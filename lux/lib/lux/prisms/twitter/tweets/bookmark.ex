defmodule Lux.Prisms.Twitter.Tweets.Bookmark do
  @moduledoc "Prism for adding or removing a bookmark."

  use Lux.Prism,
    name: "Bookmark Tweet",
    description: "Adds or removes a bookmark on a tweet",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        tweet_id: %{type: :string, description: "Tweet to bookmark"},
        action: %{type: :string, enum: ["create", "remove"], default: "create"}
      },
      required: ["user_id", "tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, tweet_id: tid, action: "remove"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/bookmarks/" <> tid, %{})
  end

  def handler(%{user_id: uid, tweet_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/bookmarks", %{json: %{tweet_id: tid}})
  end
end
