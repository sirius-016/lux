defmodule Lux.Prisms.Discord.BulkDeleteMessages do
  @moduledoc "Bulk delete multiple Discord messages."
  use Lux.Prism,
    name: "Discord Bulk Delete Messages",
    description: "Deletes multiple messages from a channel (2-100 messages, must be younger than 14 days).",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        message_ids: %{type: :array, description: "Array of message IDs to delete (2-100)"}
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted_count: %{type: :integer}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch, "message_ids" => ids} = input, _ctx) do
    ids = Enum.take(ids, 100)
    if length(ids) < 2 do
      {:error, "bulk delete requires at least 2 message IDs"}
    else
      case Client.request(:post, "/channels/#{ch}/messages/bulk-delete", %{json: %{messages: ids}}) do
        {:ok, _} -> {:ok, %{deleted_count: length(ids)}}
        {:error, reason} -> {:error, "Bulk delete failed: #{inspect(reason)}"}
      end
    end
  end
end
