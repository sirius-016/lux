defmodule Lux.Lenses.Twitter.GetMentions do
  @moduledoc """
  Lens for fetching tweets mentioning the authenticated user.

  ## Examples

      GetMentions.focus(%{user_id: "1234567890", max_results: 20})
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Mentions Timeline",
    description: "Fetches tweets mentioning the authenticated user",
    url: "https://api.twitter.com/2/users/:user_id/mentions",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Auth user ID"},
        max_results: %{type: :integer, description: "Max results (5-100)", default: 10},
        pagination_token: %{type: :string, description: "Next page token"},
        start_time: %{type: :string, description: "Start time ISO 8601"},
        end_time: %{type: :string, description: "End time ISO 8601"},
        "tweet.fields": %{
          type: :string,
          description: "Tweet fields",
          default: "created_at,public_metrics,author_id,entities,referenced_tweets"
        },
        expansions: %{type: :string, description: "Expansions", default: "author_id,referenced_tweets_id"}
      },
      required: ["user_id"]
    }

  @impl true
  def before_focus(params) do
    user_id = params[:user_id]
    params
    |> Map.delete(:user_id)
    |> Map.put(:url, "https://api.twitter.com/2/users/" <> user_id <> "/mentions")
  end

  @impl true
  def after_focus(%{"data" => tweets, "meta" => meta}) do
    {:ok, %{tweets: tweets, meta: meta}}
  end

  def after_focus(%{"data" => tweets}), do: {:ok, %{tweets: tweets, meta: %{}}}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}
end
