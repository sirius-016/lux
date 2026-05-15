defmodule Lux.Prisms.Discord.EditChannel do
  @moduledoc "Edit a Discord channel."
  use Lux.Prism,
    name: "Discord Edit Channel",
    description: "Edits an existing Discord channel's settings.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        name: %{type: :string, description: "New channel name"},
        topic: %{type: :string, description: "New topic"},
        nsfw: %{type: :boolean, description: "NSFW flag"},
        position: %{type: :integer, description: "New position"},
        parent_id: %{type: :string, description: "New parent category ID"},
        rate_limit_per_user: %{type: :integer, description: "Slowmode seconds"},
        permission_overwrites: %{type: :array, description: "New permission overwrites"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        name: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch_id} = input, _ctx) do
    body = input
    |> Map.drop(["channel_id"])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    if map_size(body) == 0 do
      {:error, "no fields to update"}
    else
      case Client.request(:patch, "/channels/#{ch_id}", %{json: body}) do
        {:ok, ch} -> {:ok, %{id: ch["id"], name: ch["name"]}}
        {:error, reason} -> {:error, "Failed to edit channel: #{inspect(reason)}"}
      end
    end
  end
end
