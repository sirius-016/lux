defmodule Lux.Prisms.Discord.CreateThread do
  @moduledoc "Create a thread from a message or in a channel."
  use Lux.Prism,
    name: "Discord Create Thread",
    description: "Creates a new thread from an existing message or in a forum/text channel.",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID"},
        message_id: %{type: :string, description: "Message ID to create thread from (optional)"},
        name: %{type: :string, description: "Thread name (1-100 chars)"},
        auto_archive_duration: %{type: :integer, description: "Auto-archive duration in minutes (60/1440/4320/10080)"},
        type: %{type: :integer, description: "Thread type (11=public, 12=private)"},
        invitable: %{type: :boolean, description: "Whether non-moderators can add members", default: true},
        rate_limit_per_user: %{type: :integer, description: "Slowmode seconds"}
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        name: %{type: :string}
      }
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def handler(%{"channel_id" => ch_id, "message_id" => msg_id, "name" => name} = input, _ctx) do
    body = %{name: String.slice(name, 0, 100), auto_archive_duration: input["auto_archive_duration"] || 1440}
    body = maybe_add(body, "type", input["type"])
    body = maybe_add(body, "invitable", input["invitable"])
    body = maybe_add(body, "rate_limit_per_user", input["rate_limit_per_user"])

    case Client.request(:post, "/channels/#{ch_id}/messages/#{msg_id}/threads", %{json: body}) do
      {:ok, thread} -> {:ok, %{id: thread["id"], name: thread["name"]}}
      {:error, reason} -> {:error, "Failed to create thread: #{inspect(reason)}"}
    end
  end

  def handler(%{"channel_id" => ch_id, "name" => name} = input, _ctx) do
    body = %{name: String.slice(name, 0, 100), auto_archive_duration: input["auto_archive_duration"] || 1440}
    body = maybe_add(body, "type", input["type"])
    body = maybe_add(body, "invitable", input["invitable"])

    case Client.request(:post, "/channels/#{ch_id}/threads", %{json: body}) do
      {:ok, thread} -> {:ok, %{id: thread["id"], name: thread["name"]}}
      {:error, reason} -> {:error, "Failed to create thread: #{inspect(reason)}"}
    end
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
