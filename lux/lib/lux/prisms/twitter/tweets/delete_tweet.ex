defmodule Lux.Prisms.Twitter.Tweets.DeleteTweet do
  @moduledoc "Prism for deleting a tweet."

  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet owned by the authenticated user",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "The ID of the tweet to delete"}
      },
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{tweet_id: tweet_id}, _ctx) do
    Client.request(:delete, "/tweets/" <> tweet_id, %{})
  end
end
