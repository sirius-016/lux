defmodule Lux.Lenses.YouTube.ListVideos do
  @moduledoc "List videos from a YouTube channel."
  use Lux.Lens,
    name: "YouTube List Videos",
    description: "Lists videos from a YouTube channel with optional filtering and ordering.",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Filter by channel ID"},
        my_rating: %{type: :string, description: "my_rating (liked or dislike)", enum: ["like", "dislike"]},
        video_id: %{type: :string, description: "Single video ID"},
        part: %{type: :string, description: "Comma-separated parts (snippet,contentDetails,statistics,liveStreamingDetails)", default: "snippet,statistics"},
        max_results: %{type: :integer, description: "Max results (1-50)", default: 20},
        order: %{type: :string, description: "Sort order", enum: ["date", "rating", "viewCount", "title"], default: "date"}
      }
    }

  @impl true
  def before_focus(params) do
    base = %{"part" => params["part"] || "snippet,statistics"}
    base = if params["max_results"], do: Map.put(base, "maxResults", params["max_results"]), else: base
    base = if params["order"], do: Map.put(base, "order", params["order"]), else: base
    base = cond do
      params["channel_id"] -> Map.put(base, "channelId", params["channel_id"])
      params["my_rating"] -> Map.put(base, "myRating", params["my_rating"])
      params["video_id"] -> Map.put(base, "id", params["video_id"])
      true -> base
    end
    %{"url" => "https://www.googleapis.com/youtube/v3/videos", "params" => base}
  end

  @impl true
  def after_focus(%{"items" => items, "pageInfo" => page_info}) do
    videos = Enum.map(items, &normalize_video/1)
    {:ok, %{videos: videos, total: page_info["totalResults"], page_info: %{
      results_per_page: page_info["resultsPerPage"]
    }}}
  end

  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}

  defp normalize_video(item) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}
    details = item["contentDetails"] || %{}
    live = item["liveStreamingDetails"] || %{}
    %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      thumbnail: snippet["thumbnails"] |> Map.values() |> List.first() |> Map.get("url"),
      tags: snippet["tags"] || [],
      duration: details["duration"],
      view_count: String.to_integer(stats["viewCount"] || "0"),
      like_count: String.to_integer(stats["likeCount"] || "0"),
      comment_count: String.to_integer(stats["commentCount"] || "0"),
      scheduled_start_time: live["scheduledStartTime"],
      concurrent_viewers: live["concurrentViewers"]
    }
  end
end
