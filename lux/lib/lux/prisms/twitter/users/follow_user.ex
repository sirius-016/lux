defmodule Lux.Prisms.Twitter.Users.FollowUser do
  @moduledoc "Prism for following or unfollowing a user."

  use Lux.Prism,
    name: "Follow User",
    description: "Follows or unfollows a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        target_user_id: %{type: :string, description: "User to follow/unfollow"},
        action: %{type: :string, enum: ["follow", "unfollow"], default: "follow"}
      },
      required: ["user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, target_user_id: tid, action: "unfollow"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/following/" <> tid, %{})
  end

  def handler(%{user_id: uid, target_user_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/following", %{json: %{target_user_id: tid}})
  end
end
