defmodule Lux.Prisms.Twitter.Users.MuteUser do
  @moduledoc "Prism for muting or unmuting a user."

  use Lux.Prism,
    name: "Mute User",
    description: "Mutes or unmutes a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        target_user_id: %{type: :string, description: "User to mute/unmute"},
        action: %{type: :string, enum: ["mute", "unmute"], default: "mute"}
      },
      required: ["user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, target_user_id: tid, action: "unmute"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/muting/" <> tid, %{})
  end

  def handler(%{user_id: uid, target_user_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/muting", %{json: %{target_user_id: tid}})
  end
end
