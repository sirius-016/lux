defmodule Lux.Beams.Discord.ModerationWorkflow do
  @moduledoc """
  Automated moderation workflow that processes messages through content filtering,
  applies warnings, and escalates to timeout/ban if thresholds are exceeded.
  """

  use Lux.Beam,
    name: "Discord Moderation Workflow",
    description: "Processes a reported message through moderation steps: analyze, warn, escalate.",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        channel_id: %{type: :string},
        message_id: %{type: :string},
        user_id: %{type: :string},
        reason: %{type: :string},
        severity: %{type: :string, enum: ["low", "medium", "high"]}
      },
      required: ["guild_id", "channel_id", "message_id", "user_id", "reason", "severity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action_taken: %{type: :string},
        message_id: %{type: :string}
      }
    },
    generate_execution_log: true

  sequence do
    step(:delete_message, Lux.Prisms.Discord.DeleteMessage, %{
      channel_id: :channel_id,
      message_id: :message_id
    })

    step(:warn_user, Lux.Prisms.Discord.SendMessage, %{
      channel_id: :channel_id,
      content: {:fn, &build_warning/1}
    }, retries: 2)

    branch {__MODULE__, :escalate?} do
      "timeout" ->
        step(:timeout, Lux.Prisms.Discord.TimeoutMember, %{
          guild_id: :guild_id,
          user_id: :user_id,
          duration_seconds: {:fn, &timeout_duration/1}
        })
      "ban" ->
        step(:ban, Lux.Prisms.Discord.BanMember, %{
          guild_id: :guild_id,
          user_id: :user_id,
          reason: :reason
        })
    end
  end

  defp build_warning(ctx) do
    "User <@#{ctx.user_id}> has been warned: #{ctx.reason}"
  end

  def escalate?(ctx) do
    case ctx.severity do
      "high" -> "ban"
      "medium" -> "timeout"
      _ -> nil
    end
  end

  defp timeout_duration(ctx) do
    case ctx.severity do
      "medium" -> 3600
      "high" -> 86400
      _ -> 1800
    end
  end
end
