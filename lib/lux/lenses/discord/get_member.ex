defmodule Lux.Lenses.Discord.GetMember do
  @moduledoc "Fetch information about a guild member."
  use Lux.Lens,
    name: "Discord Get Member",
    description: "Retrieves information about a specific guild member.",
    url: "https://discord.com/api/v10/guilds/:guild_id/members/:user_id",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID"},
        user_id: %{type: :string, description: "The user ID"}
      },
      required: ["guild_id", "user_id"]
    }

  @impl true
  def after_focus(member) when is_map(member) do
    {:ok, %{
      user: %{
        id: member["user"]["id"],
        username: member["user"]["username"],
        discriminator: member["user"]["discriminator"],
        avatar: member["user"]["avatar"],
        bot: member["user"]["bot"]
      },
      nick: member["nick"],
      roles: member["roles"],
      joined_at: member["joined_at"],
      deaf: member["deaf"],
      mute: member["mute"],
      pending: member["pending"],
      communication_disabled_until: member["communication_disabled_until"]
    }}
  end

  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}
end
