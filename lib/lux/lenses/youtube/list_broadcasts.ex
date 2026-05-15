defmodule Lux.Lenses.YouTube.ListBroadcasts do
  @moduledoc "List YouTube live broadcasts."
  use Lux.Lens,
    name: "YouTube List Broadcasts",
    description: "Lists live broadcasts from the authenticated channel.",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        broadcast_status: %{type: :string, description: "Filter by status", enum: ["all", "completed", "active", "upcoming"], default: "all"},
        mine: %{type: :boolean, description: "My broadcasts", default: true},
        max_results: %{type: :integer, description: "Max results", default: 20}
      }
    }

  @impl true
  def before_focus(params) do
    p = %{"part" => "snippet,contentDetails,status", "mine" => if(params["mine"] || true, do: "true", else: "false")}
    p = if params["broadcast_status"], do: Map.put(p, "broadcastStatus", params["broadcast_status"]), else: p
    p = if params["max_results"], do: Map.put(p, "maxResults", params["max_results"]), else: p
    %{"url" => "https://www.googleapis.com/youtube/v3/liveBroadcasts", "params" => p}
  end

  @impl true
  def after_focus(%{"items" => items}) do
    broadcasts = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      status = item["status"] || %{}
      %{
        id: item["id"],
        title: snippet["title"],
        description: snippet["description"],
        scheduled_start_time: snippet["scheduledStartTime"],
        actual_start_time: snippet["actualStartTime"],
        actual_end_time: snippet["actualEndTime"],
        broadcast_status: status["lifeCycleStatus"],
        monitoring_enabled: status["monitorStream"]["enableMonitorStream"],
        bounded: status["lifeCycleStatus"]
      }
    end)
    {:ok, %{broadcasts: broadcasts, count: length(broadcasts)}}
  end

  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}
end
