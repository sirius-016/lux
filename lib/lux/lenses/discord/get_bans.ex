defmodule Lux.Lenses.Discord.GetBans do
  @moduledoc "List banned users in a guild."
  use Lux.Lens,
    name: "Discord Get Bans",
    description: "Retrieves a list of banned users from a guild.",
    url: "https://discord.com/api/v10/guilds/:guild_id/bans",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID"},
        limit: %{type: :integer, description: "Number of bans to return", default: 50},
        before: %{type: :string, description: "Before this user ID for pagination"}
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(bans) when is_list(bans) do
    {:ok, %{
      bans: Enum.map(bans, fn b ->
        %{user: b["user"], reason: b["reason"]}
      end),
      count: length(bans)
    }}
  end

  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}
end
