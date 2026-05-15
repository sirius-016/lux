defmodule Lux.Prisms.Discord.AddReaction do
  @moduledoc "Add a reaction to a Discord message."
  use Lux.Prism,
    name: "Discord Add Reaction",
    description: "Adds an emoji reaction to a message.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        message_id: %{type: :string, description: "Message ID"},
        emoji: %{type: :string, description: "Emoji (e.g. \"thumbsup\" or \"%F0%9F%91%8D\")"}
      },
      required: ["channel_id", "message_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        added: %{type: :boolean},
        emoji: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch, "message_id" => msg_id, "emoji" => emoji}, _ctx) do
    encoded = URI.encode(emoji)
    case Client.request(:put, "/channels/#{ch}/messages/#{msg_id}/reactions/#{encoded}/@me", %{}) do
      {:ok, _} -> {:ok, %{added: true, emoji: emoji}}
      {:error, reason} -> {:error, "Failed to add reaction: #{inspect(reason)}"}
    end
  end
end
