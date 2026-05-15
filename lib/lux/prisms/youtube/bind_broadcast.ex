defmodule Lux.Prisms.YouTube.BindBroadcast do
  @moduledoc "Bind a broadcast to a stream."
  use Lux.Prism,
    name: "YouTube Bind Broadcast",
    description: "Binds a live broadcast to a live stream configuration.",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        stream_id: %{type: :string, description: "Stream ID"}
      },
      required: ["broadcast_id", "stream_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        stream_id: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"broadcast_id" => bid, "stream_id" => sid}, _ctx) do
    case Client.request(:post, "/liveBroadcasts/#{bid}/bind", %{
      params: %{"id" => bid, "streamId" => sid, "part" => "snippet,contentDetails,status"}
    }) do
      {:ok, %{"id" => id, "snippet" => snippet}} ->
        {:ok, %{id: id, stream_id: snippet["boundStreamId"]}}
      {:error, reason} ->
        {:error, "Failed to bind broadcast: #{inspect(reason)}"}
    end
  end
end
