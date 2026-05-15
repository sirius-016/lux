defmodule Lux.Prisms.Twitter.Users.BlockUser do
  @moduledoc "Prism for blocking or unblocking a user."

  use Lux.Prism,
    name: "Block User",
    description: "Blocks or unblocks a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "Authenticated user ID"},
        target_user_id: %{type: :string, description: "User to block/unblock"},
        action: %{type: :string, enum: ["block", "unblock"], default: "block"}
      },
      required: ["user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{user_id: uid, target_user_id: tid, action: "unblock"}, _ctx) do
    Client.request(:delete, "/users/" <> uid <> "/blocking/" <> tid, %{})
  end

  def handler(%{user_id: uid, target_user_id: tid}, _ctx) do
    Client.request(:post, "/users/" <> uid <> "/blocking", %{json: %{target_user_id: tid}})
  end
end
