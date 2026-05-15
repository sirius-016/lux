defmodule Lux.Prisms.Discord.TimeoutMember do
  @moduledoc "Timeout (mute) a guild member."
  use Lux.Prism,
    name: "Discord Timeout Member",
    description: "Times out a guild member, preventing them from sending messages and joining voice channels.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        user_id: %{type: :string, description: "User ID to timeout"},
        duration_seconds: %{type: :integer, description: "Timeout duration in seconds (max 604800 = 7 days)"},
        reason: %{type: :string, description: "Reason for the timeout"}
      },
      required: ["guild_id", "user_id", "duration_seconds"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string},
        communication_disabled_until: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "user_id" => uid, "duration_seconds" => dur} = input, _ctx) do
    duration = min(dur, 604800)
    disabled_until = DateTime.utc_now() |> DateTime.add(duration, :second) |> DateTime.to_iso8601()
    headers = if input["reason"], do: [{"X-Audit-Log-Reason", input["reason"]}], else: []

    case Client.request(:patch, "/guilds/#{gid}/members/#{uid}", %{
      json: %{communication_disabled_until: disabled_until},
      headers: headers
    }) do
      {:ok, _} -> {:ok, %{user_id: uid, communication_disabled_until: disabled_until}}
      {:error, reason} -> {:error, "Failed to timeout member: #{inspect(reason)}"}
    end
  end
end
