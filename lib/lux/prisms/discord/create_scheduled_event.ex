defmodule Lux.Prisms.Discord.CreateScheduledEvent do
  @moduledoc "Create a scheduled event in a guild."
  use Lux.Prism,
    name: "Discord Create Scheduled Event",
    description: "Creates a new scheduled event in a guild.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        name: %{type: :string, description: "Event name (1-100 chars)"},
        description: %{type: :string, description: "Event description (1-1000 chars)"},
        scheduled_start_time: %{type: :string, description: "ISO 8601 start time"},
        scheduled_end_time: %{type: :string, description: "ISO 8601 end time (required for external events)"},
        entity_type: %{type: :integer, description: "Entity type (1=stage, 2=voice, 3=external)"},
        channel_id: %{type: :string, description: "Channel ID (for stage/voice events)"},
        entity_metadata: %{type: :object, description: "Entity metadata (location for external events)"},
        image: %{type: :string, description: "Cover image base64 or data URI"}
      },
      required: ["guild_id", "name", "scheduled_start_time", "entity_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        name: %{type: :string},
        status: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "name" => name} = input, _ctx) do
    body = %{name: String.slice(name, 0, 100)}
    body = maybe_add(body, "description", input["description"])
    body = maybe_add(body, "scheduled_start_time", input["scheduled_start_time"])
    body = maybe_add(body, "scheduled_end_time", input["scheduled_end_time"])
    body = maybe_add(body, "entity_type", input["entity_type"])
    body = maybe_add(body, "channel_id", input["channel_id"])
    body = maybe_add(body, "entity_metadata", input["entity_metadata"])
    body = maybe_add(body, "image", input["image"])
    body = Map.put(body, "privacy_level", 2)

    case Client.request(:post, "/guilds/#{gid}/scheduled-events", %{json: body}) do
      {:ok, evt} -> {:ok, %{id: evt["id"], name: evt["name"], status: evt["status"]}}
      {:error, reason} -> {:error, "Failed to create event: #{inspect(reason)}"}
    end
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
