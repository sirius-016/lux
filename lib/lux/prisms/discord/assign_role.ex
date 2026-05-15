defmodule Lux.Prisms.Discord.AssignRole do
  @moduledoc "Assign or remove a role from a guild member."
  use Lux.Prism,
    name: "Discord Assign Role",
    description: "Assigns or removes a role from a guild member.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        user_id: %{type: :string, description: "User ID"},
        role_id: %{type: :string, description: "Role ID"},
        action: %{type: :string, description: "assign or remove", enum: ["assign", "remove"]}
      },
      required: ["guild_id", "user_id", "role_id", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string},
        role_id: %{type: :string},
        action: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "user_id" => uid, "role_id" => rid, "action" => action}, _ctx) do
    method = if action == "assign", do: :put, else: :delete

    case Client.request(method, "/guilds/#{gid}/members/#{uid}/roles/#{rid}", %{}) do
      {:ok, _} -> {:ok, %{user_id: uid, role_id: rid, action: action}}
      {:error, reason} -> {:error, "Failed to #{action} role: #{inspect(reason)}"}
    end
  end
end
