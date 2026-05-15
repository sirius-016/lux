defmodule Lux.Prisms.Discord.SendMessage do
  @moduledoc "Send a message to a Discord channel."
  use Lux.Prism,
    name: "Discord Send Message",
    description: "Sends a message to a specified Discord channel with optional embeds, components, and files.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Target channel ID"},
        content: %{type: :string, description: "Message content (max 2000 chars)"},
        embeds: %{type: :array, description: "Array of embed objects"},
        components: %{type: :array, description: "Array of message component rows"},
        tts: %{type: :boolean, description: "Text-to-speech", default: false},
        message_reference: %{type: :object, description: "Reference another message for replies"}
      },
      required: ["channel_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        channel_id: %{type: :string},
        content: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => channel_id} = input, _ctx) do
    body = build_body(input)

    case Client.request(:post, "/channels/#{channel_id}/messages", %{json: body}) do
      {:ok, msg} -> {:ok, %{id: msg["id"], channel_id: msg["channel_id"], content: msg["content"]}}
      {:error, reason} -> {:error, "Failed to send message: #{inspect(reason)}"}
    end
  end

  defp build_body(input) do
    base = %{content: String.slice(input["content"], 0, 2000)}

    base
    |> maybe_add("tts", Map.get(input, "tts"))
    |> maybe_add("embeds", Map.get(input, "embeds"))
    |> maybe_add("components", Map.get(input, "components"))
    |> maybe_add("message_reference", Map.get(input, "message_reference"))
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
