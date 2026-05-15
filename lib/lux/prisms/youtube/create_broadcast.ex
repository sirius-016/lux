defmodule Lux.Prisms.YouTube.CreateBroadcast do
  @moduledoc "Create a YouTube live broadcast."
  use Lux.Prism,
    name: "YouTube Create Broadcast",
    description: "Creates a new YouTube live broadcast event.",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Broadcast title"},
        description: %{type: :string, description: "Broadcast description"},
        scheduled_start_time: %{type: :string, description: "ISO 8601 scheduled start time"},
        privacy_status: %{type: :string, description: "Privacy status", enum: ["public", "unlisted", "private"], default: "private"},
        auto_stop: %{type: :string, description: "Auto stop time (ISO 8601)"}
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        title: %{type: :string},
        stream_id: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"title" => title, "scheduled_start_time" => start_time} = input, _ctx) do
    body = %{
      snippet: %{
        title: String.slice(title, 0, 100),
        description: String.slice(input["description"] || "", 0, 5000),
        scheduledStartTime: start_time
      },
      status: %{
        privacyStatus: input["privacy_status"] || "private",
        selfDeclaredMadeForKids: false
      }
    }

    case Client.request(:post, "/liveBroadcasts", %{
      json: body,
      params: %{"part" => "snippet,status"}
    }) do
      {:ok, %{"id" => id, "snippet" => snippet}} ->
        {:ok, %{id: id, title: snippet["title"], stream_id: snippet["boundStreamId"]}}
      {:error, reason} ->
        {:error, "Failed to create broadcast: #{inspect(reason)}"}
    end
  end
end
