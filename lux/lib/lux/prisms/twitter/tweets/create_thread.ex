defmodule Lux.Prisms.Twitter.Tweets.CreateThread do
  @moduledoc """
  Prism for creating a tweet thread (multiple tweets as a reply chain).
  """

  use Lux.Prism,
    name: "Create Tweet Thread",
    description: "Creates a thread of tweets connected by reply chains",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          items: %{type: :string},
          description: "Array of tweet texts in thread order (max 280 chars each)",
          minItems: 2,
          maxItems: 25
        }
      },
      required: ["tweets"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{tweets: tweets}, _ctx) do
    tweets
    |> Enum.reduce_while({:ok, []}, fn text, {:ok, results} ->
      body = case results do
        [] -> %{text: text}
        [{prev_id, _} | _] -> %{text: text, reply: %{in_reply_to_tweet_id: prev_id}}
      end

      case Client.request(:post, "/tweets", %{json: body}) do
        {:ok, %{"data" => %{"id" => id}}} ->
          {:cont, {:ok, [{id, text} | results]}}
        {:error, reason} ->
          {:halt, {:error, {:thread_failed, length(results), reason}}}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, %{tweets: Enum.reverse(results)}}
      error -> error
    end
  end
end
