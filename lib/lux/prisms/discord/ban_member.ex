defmodule Lux.Prisms.Discord.BanMember do
  @moduledoc "Ban a member from a guild."
  use Lux.Prism,
    name: "Discord Ban Member",
    description: "Bans a user from a guild with optional message deletion and reason.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        user_id: %{type: :string, description: "User ID to ban"},
        delete_message_days: %{type: :integer, description: "Delete messages from last N days (0-7)", default: 0},
        reason: %{type: :string, description: "Ban reason"}
      },
      required: ["guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean},
        user_id: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "user_id" => uid} = input, _ctx) do
    body = %{delete_message_days: input["delete_message_days"] || 0}
    headers = if input["reason"], do: [{"X-Audit-Log-Reason", input["reason"]}], else: []

    case Client.request(:put, "/guilds/#{gid}/bans/#{uid}", %{json: body, headers: headers}) do
      {:ok, _} -> {:ok, %{banned: true, user_id: uid}}
      {:error, reason} -> {:error, "Failed to ban member: #{inspect(reason)}"}
    end
  end
end
