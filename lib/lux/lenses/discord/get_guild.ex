defmodule Lux.Lenses.Discord.GetGuild do
  @moduledoc "Fetch information about a Discord guild (server)."
  use Lux.Lens,
    name: "Discord Get Guild",
    description: "Retrieves information about a Discord guild/server.",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID"},
        with_counts: %{type: :boolean, description: "Include approximate member and presence counts"}
      },
      required: ["guild_id"]
    }

  @impl true
  def before_focus(%{"guild_id" => gid, "with_counts" => true} = params) do
    %{"guild_id" => gid, "with_counts" => "true"}
  end

  def before_focus(%{"guild_id" => gid}), do: %{"guild_id" => gid}

  @impl true
  def after_focus(guild) when is_map(guild) do
    {:ok, %{
      id: guild["id"],
      name: guild["name"],
      icon: guild["icon"],
      description: guild["description"],
      owner_id: guild["owner_id"],
      member_count: guild["member_count"],
      approximate_member_count: guild["approximate_member_count"],
      approximate_presence_count: guild["approximate_presence_count"],
      roles: guild["roles"] || [],
      premium_tier: guild["premium_tier"],
      nsfw_level: guild["nsfw_level"],
      features: guild["features"] || []
    }}
  end

  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}
end
