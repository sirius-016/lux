defmodule Lux.Beams.YouTube.AutoLiveWorkflow do
  @moduledoc """
  Automated YouTube live streaming workflow:
  1. Create a stream configuration
  2. Create broadcast
  3. Bind broadcast to stream
  4. Transition to testing
  Returns the stream key for OBS/XSplit configuration.
  """

  use Lux.Beam,
    name: "YouTube Auto-Live Workflow",
    description: "Creates and configures a YouTube live broadcast automatically.",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        scheduled_start_time: %{type: :string, description: "ISO 8601"},
        privacy_status: %{type: :string, enum: ["public", "unlisted", "private"], default: "public"}
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string},
        stream_id: %{type: :string},
        stream_key: %{type: :string}
      }
    },
    generate_execution_log: true

  sequence do
    step(:create_stream, Lux.Prisms.YouTube.CreateStream, %{
      title: :title,
      description: :description,
      privacy_status: :privacy_status
    })

    step(:create_broadcast, Lux.Prisms.YouTube.CreateBroadcast, %{
      title: :title,
      description: :description,
      scheduled_start_time: :scheduled_start_time,
      privacy_status: :privacy_status
    })

    step(:bind, Lux.Prisms.YouTube.BindBroadcast, %{
      broadcast_id: {:ref, "create_broadcast.broadcast_id"},
      stream_id: {:ref, "create_stream.stream_id"}
    })

    step(:transition_testing, Lux.Prisms.YouTube.TransitionBroadcast, %{
      broadcast_id: {:ref, "create_broadcast.broadcast_id"},
      status: "testing"
    })
  end
end
