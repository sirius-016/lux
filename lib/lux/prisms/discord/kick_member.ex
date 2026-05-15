defmodule Lux.Prisms.Discord.KickMember do
  @moduledoc "Kick a member from a guild."
  use Lux.Prism,
    name: "Discord Kick Member",
    description: "Kicks a member from a guild.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        user_id: %{type: :string, description: "User ID to kick"},
        reason: %{type: :string, description: "Reason for kick"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        kicked: %{type: :boolean},
        user_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "user_id" => uid} = input, _ctx) do
    headers = if input["reason"], do: [{"X-Audit-Log-Reason", input["reason"]}], else: []

    case Client.request(:delete, "/guilds/#{gid}/members/#{uid}", %{headers: headers}) do
      {:ok, _} -> {:ok, %{kicked: true, user_id: uid}}
      {:error, reason} -> {:error, "Failed to kick member: #{inspect(reason)}"}
    end
  end
end
