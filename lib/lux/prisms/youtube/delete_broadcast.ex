defmodule Lux.Prisms.YouTube.DeleteBroadcast do
  @moduledoc "Delete a YouTube live broadcast."
  use Lux.Prism,
    name: "YouTube Delete Broadcast",
    description: "Deletes a live broadcast from the channel.",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Broadcast ID to delete"}
      },
      required: ["broadcast_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        broadcast_id: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"broadcast_id" => id}, _ctx) do
    case Client.request(:delete, "/liveBroadcasts", %{
      params: %{"id" => id, "part" => "status"}
    }) do
      {:ok, _} -> {:ok, %{deleted: true, broadcast_id: id}}
      {:error, reason} -> {:error, "Failed to delete broadcast: #{inspect(reason)}"}
    end
  end
end
