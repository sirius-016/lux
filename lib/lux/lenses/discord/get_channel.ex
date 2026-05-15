defmodule Lux.Lenses.Discord.GetChannel do
  @moduledoc "Fetch information about a Discord channel."
  use Lux.Lens,
    name: "Discord Get Channel",
    description: "Retrieves detailed information about a specific Discord channel.",
    url: "https://discord.com/api/v10/channels/:channel_id",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The channel ID"}
      },
      required: ["channel_id"]
    }

  @impl true
  def after_focus(channel) when is_map(channel) do
    {:ok, %{
      id: channel["id"],
      name: channel["name"],
      type: channel["type"],
      topic: channel["topic"],
      guild_id: channel["guild_id"],
      position: channel["position"],
      nsfw: channel["nsfw"],
      parent_id: channel["parent_id"],
      rate_limit_per_user: channel["rate_limit_per_user"],
      last_message_id: channel["last_message_id"],
      permission_overwrites: channel["permission_overwrites"] || []
    }}
  end

  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}
end
