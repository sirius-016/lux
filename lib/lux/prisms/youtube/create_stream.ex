defmodule Lux.Prisms.YouTube.CreateStream do
  @moduledoc "Create a YouTube live stream configuration."
  use Lux.Prism,
    name: "YouTube Create Stream",
    description: "Creates a live stream configuration to bind to broadcasts.",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Stream title"},
        description: %{type: :string, description: "Stream description"},
        privacy_status: %{type: :string, enum: ["public", "unlisted", "private"], default: "unlisted"}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        title: %{type: :string},
        stream_key: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"title" => title} = input, _ctx) do
    body = %{
      snippet: %{
        title: String.slice(title, 0, 100),
        description: String.slice(input["description"] || "", 0, 5000)
      },
      content_details: %{
        streamType: "live",
        privacyStatus: input["privacy_status"] || "unlisted",
        selfDeclaredMadeForKids: false
      }
    }

    case Client.request(:post, "/liveStreams", %{
      json: body,
      params: %{"part" => "snippet,contentDetails"}
    }) do
      {:ok, %{"id" => id, "snippet" => snippet, "contentDetails" => details}} ->
        {:ok, %{id: id, title: snippet["title"], stream_key: details["streamKeys"] |> List.first()}}
      {:error, reason} ->
        {:error, "Failed to create stream: #{inspect(reason)}"}
    end
  end
end
