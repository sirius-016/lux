defmodule Lux.Lenses.Twitter.GetTweet do
  @moduledoc """
  Lens for fetching a single tweet by ID from Twitter API v2.

  ## Examples

      GetTweet.focus(%{tweet_id: "1234567890"})
      GetTweet.focus(%{tweet_id: "1234567890", expansions: "author_id,referenced_tweets_id"})
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Tweet",
    description: "Fetches a tweet by ID from Twitter API v2",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "The ID of the tweet to retrieve"},
        expansions: %{
          type: :string,
          description: "Comma-separated list of expansions",
          default: "author_id"
        },
        "tweet.fields": %{
          type: :string,
          description: "Comma-separated list of tweet fields to return",
          default: "created_at,public_metrics,entities,context_annotations"
        },
        "user.fields": %{
          type: :string,
          description: "Comma-separated list of user fields for author expansion",
          default: "name,username,profile_image_url,verified"
        }
      },
      required: ["tweet_id"]
    }

  @impl true
  def after_focus(%{"data" => tweet}) do
    {:ok, format_tweet(tweet)}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}

  defp format_tweet(tweet) do
    %{
      id: tweet["id"],
      text: tweet["text"],
      author_id: tweet["author_id"],
      created_at: tweet["created_at"],
      public_metrics: tweet["public_metrics"],
      entities: tweet["entities"],
      context_annotations: tweet["context_annotations"]
    }
  end
end
