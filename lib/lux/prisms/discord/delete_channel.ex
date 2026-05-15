defmodule Lux.Prisms.Discord.DeleteChannel do
  @moduledoc "Delete a Discord channel."
  use Lux.Prism,
    name: "Discord Delete Channel",
    description: "Deletes a Discord channel. This cannot be undone.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID to delete"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        channel_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch_id}, _ctx) do
    case Client.request(:delete, "/channels/#{ch_id}", %{}) do
      {:ok, _} -> {:ok, %{deleted: true, channel_id: ch_id}}
      {:error, reason} -> {:error, "Failed to delete channel: #{inspect(reason)}"}
    end
  end
end
