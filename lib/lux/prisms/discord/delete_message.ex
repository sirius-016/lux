defmodule Lux.Prisms.Discord.DeleteMessage do
  @moduledoc "Delete a Discord message."
  use Lux.Prism,
    name: "Discord Delete Message",
    description: "Deletes a message from a Discord channel.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        message_id: %{type: :string, description: "Message ID to delete"}
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        message_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch, "message_id" => msg_id}, _ctx) do
    case Client.request(:delete, "/channels/#{ch}/messages/#{msg_id}", %{}) do
      {:ok, _} -> {:ok, %{deleted: true, message_id: msg_id}}
      {:error, reason} -> {:error, "Failed to delete message: #{inspect(reason)}"}
    end
  end
end
