defmodule Lux.Lenses.Discord.ListChannels do
  @moduledoc "List all channels in a guild."
  use Lux.Lens,
    name: "Discord List Channels",
    description: "Lists all channels in a Discord guild/server.",
    url: "https://discord.com/api/v10/guilds/:guild_id/channels",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID"}
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(channels) when is_list(channels) do
    {:ok, %{
      channels: Enum.map(channels, fn ch ->
        %{id: ch["id"], name: ch["name"], type: ch["type"], position: ch["position"],
          topic: ch["topic"], parent_id: ch["parent_id"], nsfw: ch["nsfw"]}
      end),
      count: length(channels)
    }}
  end

  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}
end
