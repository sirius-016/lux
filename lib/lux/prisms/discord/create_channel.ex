defmodule Lux.Prisms.Discord.CreateChannel do
  @moduledoc "Create a new Discord channel."
  use Lux.Prism,
    name: "Discord Create Channel",
    description: "Creates a new channel in a Discord guild.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        name: %{type: :string, description: "Channel name (1-100 chars)"},
        type: %{type: :integer, description: "Channel type (0=text, 2=voice, 13=stage, 15=forum)", default: 0},
        topic: %{type: :string, description: "Channel topic (0-1024 chars)"},
        parent_id: %{type: :string, description: "Category parent ID"},
        nsfw: %{type: :boolean, description: "NSFW channel"},
        position: %{type: :integer, description: "Sorting position"},
        permission_overwrites: %{type: :array, description: "Permission overwrites"},
        rate_limit_per_user: %{type: :integer, description: "Slowmode seconds (0-21600)"}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        name: %{type: :string},
        type: %{type: :integer}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"guild_id" => gid, "name" => name} = input, _ctx) do
    body = %{name: String.slice(name, 0, 100)}
    body = maybe_add(body, "type", input["type"])
    body = maybe_add(body, "topic", input["topic"])
    body = maybe_add(body, "parent_id", input["parent_id"])
    body = maybe_add(body, "nsfw", input["nsfw"])
    body = maybe_add(body, "position", input["position"])
    body = maybe_add(body, "permission_overwrites", input["permission_overwrites"])
    body = maybe_add(body, "rate_limit_per_user", input["rate_limit_per_user"])

    case Client.request(:post, "/guilds/#{gid}/channels", %{json: body}) do
      {:ok, ch} -> {:ok, %{id: ch["id"], name: ch["name"], type: ch["type"]}}
      {:error, reason} -> {:error, "Failed to create channel: #{inspect(reason)}"}
    end
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
