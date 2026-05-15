defmodule Lux.Prisms.Twitter.Tweets.QuoteTweet do
  @moduledoc "Prism for creating a quote tweet."

  use Lux.Prism,
    name: "Quote Tweet",
    description: "Creates a quote tweet (retweet with comment)",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Quote text (max 280 chars)"},
        quote_tweet_id: %{type: :string, description: "Tweet to quote"}
      },
      required: ["text", "quote_tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{text: text, quote_tweet_id: qt_id}, _ctx) do
    body = %{
      text: text,
      quote_tweet_id: qt_id
    }
    Client.request(:post, "/tweets", %{json: body})
  end
end
