defmodule Lux.Lenses.Twitter.GetTimeline do
  @moduledoc """
  Lens for fetching a user's tweet timeline from Twitter API v2.

  ## Examples

      GetTimeline.focus(%{user_id: "1234567890", max_results: 20})
      GetTimeline.focus(%{user_id: "123", exclude: "replies"})
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User Timeline",
    description: "Fetches tweets from a user's timeline",
    url: "https://api.twitter.com/2/users/:user_id/tweets",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "The user ID whose tweets to fetch"},
        max_results: %{type: :integer, description: "Max tweets (5-100)", default: 10},
        exclude: %{type: :string, enum: ["replies", "retweets"], description: "Exclude types"},
        start_time: %{type: :string, description: "Start time ISO 8601"},
        end_time: %{type: :string, description: "End time ISO 8601"},
        pagination_token: %{type: :string, description: "Next page token"},
        "tweet.fields": %{
          type: :string,
          description: "Tweet fields",
          default: "created_at,public_metrics,entities,context_annotations"
        },
        expansions: %{type: :string, description: "Expansions", default: "author_id"}
      },
      required: ["user_id"]
    }

  @impl true
  def before_focus(params) do
    user_id = params[:user_id]
    params
    |> Map.delete(:user_id)
    |> Map.put(:url, "https://api.twitter.com/2/users/" <> user_id <> "/tweets")
  end

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    {:ok, %{tweets: Enum.map(tweets, &format_tweet/1), meta: meta}}
  end

  def after_focus(%{"data" => tweets}), do: {:ok, %{tweets: tweets, meta: %{}}}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}

  defp format_tweet(t) do
    %{id: t["id"], text: t["text"], author_id: t["author_id"],
      created_at: t["created_at"], public_metrics: t["public_metrics"]}
  end
end
