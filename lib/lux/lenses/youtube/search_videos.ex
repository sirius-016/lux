defmodule Lux.Lenses.YouTube.SearchVideos do
  @moduledoc "Search YouTube videos and channels."
  use Lux.Lens,
    name: "YouTube Search Videos",
    description: "Searches YouTube for videos and channels matching a query.",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        q: %{type: :string, description: "Search query"},
        channel_id: %{type: :string, description: "Filter to specific channel"},
        type: %{type: :string, description: "Result type", default: "video"},
        order: %{type: :string, description: "Sort order", enum: ["relevance", "date", "rating", "viewCount"], default: "relevance"},
        published_after: %{type: :string, description: "ISO 8601 date"},
        max_results: %{type: :integer, description: "Max results (1-50)", default: 10}
      },
      required: ["q"]
    }

  @impl true
  def before_focus(params) do
    p = %{"q" => params["q"], "type" => params["type"] || "video", "part" => "snippet"}
    p = if params["channel_id"], do: Map.put(p, "channelId", params["channel_id"]), else: p
    p = if params["order"], do: Map.put(p, "order", params["order"]), else: p
    p = if params["published_after"], do: Map.put(p, "publishedAfter", params["published_after"]), else: p
    p = if params["max_results"], do: Map.put(p, "maxResults", params["max_results"]), else: p
    %{"url" => "https://www.googleapis.com/youtube/v3/search", "params" => p}
  end

  @impl true
  def after_focus(%{"items" => items}) do
    results = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      %{
        kind: item["id"]["kind"],
        video_id: item["id"]["videoId"],
        channel_id: item["snippet"]["channelId"],
        channel_title: snippet["channelTitle"],
        title: snippet["title"],
        description: snippet["description"],
        published_at: snippet["publishedAt"],
        thumbnail: get_thumbnail(snippet["thumbnails"])
      }
    end)
    {:ok, %{results: results, count: length(results)}}
  end

  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}

  defp get_thumbnail(thumbnails) do
    thumbnails["high"]["url"] || thumbnails["medium"]["url"] || thumbnails["default"]["url"]
  end
end
