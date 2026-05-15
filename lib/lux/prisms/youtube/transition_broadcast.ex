defmodule Lux.Prisms.YouTube.TransitionBroadcast do
  @moduledoc "Transition a broadcast to a new status."
  use Lux.Prism,
    name: "YouTube Transition Broadcast",
    description: "Transitions a broadcast to testing, live, or complete.",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        status: %{type: :string, description: "Target status", enum: ["testing", "live", "complete"]}
      },
      required: ["broadcast_id", "status"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        status: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"broadcast_id" => id, "status" => status}, _ctx) do
    case Client.request(:post, "/liveBroadcasts/#{id}/transition", %{
      params: %{"part" => "status", "broadcastStatus" => status}
    }) do
      {:ok, %{"id" => bid, "status" => %{"lifeCycleStatus" => s}}} ->
        {:ok, %{id: bid, status: s}}
      {:error, reason} ->
        {:error, "Failed to transition broadcast: #{inspect(reason)}"}
    end
  end
end
