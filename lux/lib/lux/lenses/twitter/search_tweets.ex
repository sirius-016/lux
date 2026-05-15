defmodule Lux.Lenses.Twitter.SearchTweets do
  @moduledoc """
  Lens for searching tweets using Twitter API v2.

  Supports both recent search (last 7 days) and full archive search.

  ## Examples

      SearchTweets.focus(%{query: "from:elonmusk lang:en"})
      SearchTweets.focus(%{query: "#Ethereum", sort_order: "relevancy", max_results: 50})
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Search Tweets",
    description: "Searches tweets using Twitter API v2 recent or full archive search",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{type: :string, description: "Twitter search query"},
        sort_order: %{
          type: :string,
          enum: ["relevancy", "recency"],
          description: "Order of results",
          default: "recency"
        },
        max_results: %{
          type: :integer,
          description: "Maximum results (10-100)",
          default: 10,
          minimum: 10,
          maximum: 100
        },
        start_time: %{type: :string, description: "Start time ISO 8601 (e.g. 2024-01-01T00:00:00Z)"},
        end_time: %{type: :string, description: "End time ISO 8601"},
        next_token: %{type: :string, description: "Pagination token from previous response"},
        "tweet.fields": %{
          type: :string,
          description: "Tweet fields to return",
          default: "created_at,public_metrics,author_id,entities,context_annotations"
        },
        expansions: %{
          type: :string,
          description: "Expansions to include",
          default: "author_id"
        },
        "user.fields": %{
          type: :string,
          description: "User fields for expansion",
          default: "name,username,verified"
        }
      },
      required: ["query"]
    }

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    formatted = Enum.map(tweets, fn tweet ->
      %{id: tweet["id"], text: tweet["text"], author_id: tweet["author_id"],
        created_at: tweet["created_at"], public_metrics: tweet["public_metrics"]}
    end)
    {:ok, %{tweets: formatted, meta: meta}}
  end

  def after_focus(%{"data" => tweets}), do: {:ok, %{tweets: tweets, meta: %{}}}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}
end
