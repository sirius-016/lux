defmodule Lux.Prisms.Twitter.Tweets.CreateTweet do
  @moduledoc """
  Prism for creating a new tweet via Twitter API v2.

  ## Examples

      CreateTweet.run(%{text: "Hello, Twitter!"})
      CreateTweet.run(%{text: "Reply", reply_in_reply_to_tweet_id: "123"})
      CreateTweet.run(%{text: "Poll", poll: %{options: ["Yes", "No"], duration_minutes: 60}})
  """

  use Lux.Prism,
    name: "Create Tweet",
    description: "Creates a new tweet with optional media, poll, or reply settings",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Tweet text (max 280 chars)"},
        media: %{
          type: :object,
          description: "Media attachments",
          properties: %{
            media_ids: %{type: :array, items: %{type: :string}},
            tagged_user_ids: %{type: :array, items: %{type: :string}}
          }
        },
        reply: %{
          type: :object,
          description: "Reply settings",
          properties: %{
            in_reply_to_tweet_id: %{type: :string},
            exclude_reply_user_ids: %{type: :array, items: %{type: :string}}
          }
        },
        poll: %{
          type: :object,
          description: "Poll configuration",
          properties: %{
            options: %{type: :array, items: %{type: :string}, minItems: 2, maxItems: 4},
            duration_minutes: %{type: :integer}
          }
        },
        geo: %{
          type: :object,
          properties: %{
            place_id: %{type: :string}
          }
        },
        reply_settings: %{
          type: :string,
          enum: ["mentionedUsers", "following"],
          description: "Who can reply"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        data: %{type: :object, properties: %{id: %{type: :string}, text: %{type: :string}}}
      }
    }

  alias Lux.Integrations.Twitter.Client

  @doc "Creates a new tweet."
  def handler(%{text: text} = input, _ctx) do
    body = build_body(input)
    Client.request(:post, "/tweets", %{json: body})
  end

  defp build_body(%{text: text} = input) do
    base = %{text: text}

    base
    |> maybe_add(:media, input[:media])
    |> maybe_add(:reply, input[:reply])
    |> maybe_add(:poll, input[:poll])
    |> maybe_add(:geo, input[:geo])
    |> maybe_add(:reply_settings, input[:reply_settings])
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
