defmodule Lux.Prisms.Discord.CancelScheduledEvent do
  @moduledoc "Cancel a scheduled guild event."
  use Lux.Prism,
    name: "Discord Cancel Scheduled Event",
    description: "Cancels an existing scheduled event.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        event_id: %{type: :string, description: "Event ID to cancel"}
      },
      required: ["guild_id", "event_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        cancelled: %{type: :boolean},
        event_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "event_id" => eid}, _ctx) do
    case Client.request(:patch, "/guilds/#{gid}/scheduled-events/#{eid}", %{json: %{status: 3}}) do
      {:ok, _} -> {:ok, %{cancelled: true, event_id: eid}}
      {:error, reason} -> {:error, "Failed to cancel event: #{inspect(reason)}"}
    end
  end
end
