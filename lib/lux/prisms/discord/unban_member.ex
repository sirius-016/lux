defmodule Lux.Prisms.Discord.UnbanMember do
  @moduledoc "Unban a user from a guild."
  use Lux.Prism,
    name: "Discord Unban Member",
    description: "Removes a ban from a user in a guild.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        user_id: %{type: :string, description: "User ID to unban"},
        reason: %{type: :string, description: "Reason for unbanning"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unbanned: %{type: :boolean},
        user_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "user_id" => uid} = input, _ctx) do
    headers = if input["reason"], do: [{"X-Audit-Log-Reason", input["reason"]}], else: []

    case Client.request(:delete, "/guilds/#{gid}/bans/#{uid}", %{headers: headers}) do
      {:ok, _} -> {:ok, %{unbanned: true, user_id: uid}}
      {:error, reason} -> {:error, "Failed to unban member: #{inspect(reason)}"}
    end
  end
end
