defmodule Lux.Prisms.Discord.EditMessage do
  @moduledoc "Edit an existing Discord message."
  use Lux.Prism,
    name: "Discord Edit Message",
    description: "Edits an existing message in a Discord channel.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        message_id: %{type: :string, description: "Message ID to edit"},
        content: %{type: :string, description: "New message content (max 2000 chars)"},
        embeds: %{type: :array, description: "New embeds array"},
        flags: %{type: :integer, description: "Message flags"}
      },
      required: ["channel_id", "message_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        content: %{type: :string},
        edited_timestamp: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch, "message_id" => msg_id, "content" => content} = input, _ctx) do
    body = %{content: String.slice(content, 0, 2000)}
    body = if input["embeds"], do: Map.put(body, :embeds, input["embeds"]), else: body
    body = if input["flags"], do: Map.put(body, :flags, input["flags"]), else: body

    case Client.request(:patch, "/channels/#{ch}/messages/#{msg_id}", %{json: body}) do
      {:ok, msg} -> {:ok, %{id: msg["id"], content: msg["content"], edited_timestamp: msg["edited_timestamp"]}}
      {:error, reason} -> {:error, "Failed to edit message: #{inspect(reason)}"}
    end
  end
end
