defmodule Lux.Beams.Discord.ChannelSetupWorkflow do
  @moduledoc """
  Workflow to set up a new Discord channel with proper permissions, topic, and slowmode.
  """

  use Lux.Beam,
    name: "Discord Channel Setup Workflow",
    description: "Creates and configures a new Discord channel with permissions and settings.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        name: %{type: :string},
        topic: %{type: :string},
        nsfw: %{type: :boolean, default: false},
        slowmode: %{type: :integer, default: 0},
        parent_id: %{type: :string}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        name: %{type: :string}
      }
    },
    generate_execution_log: true

  sequence do
    step(:create, Lux.Prisms.Discord.CreateChannel, %{
      guild_id: :guild_id,
      name: :name,
      topic: :topic,
      nsfw: :nsfw,
      rate_limit_per_user: :slowmode,
      parent_id: :parent_id
    })
  end
end
