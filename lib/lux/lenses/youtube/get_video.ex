defmodule Lux.Lenses.YouTube.GetVideo do
  @moduledoc "Get details for a single YouTube video."
  use Lux.Lens,
    name: "YouTube Get Video",
    description: "Retrieves detailed information about a specific YouTube video.",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string, description: "YouTube video ID"},
        part: %{type: :string, description: "Comma-separated parts", default: "snippet,contentDetails,statistics,liveStreamingDetails"}
      },
      required: ["video_id"]
    }

  @impl true
  def before_focus(%{"video_id" => vid} = params) do
    %{"url" => "https://www.googleapis.com/youtube/v3/videos",
      "params" => %{"id" => vid, "part" => params["part"] || "snippet,contentDetails,statistics,liveStreamingDetails"}}
  end

  @impl true
  def after_focus(%{"items" => [item | _]}) do
    {:ok, normalize_video(item)}
  end

  def after_focus(%{"items" => []}), do: {:error, "Video not found"}
  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}

  defp normalize_video(item) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}
    %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      tags: snippet["tags"] || [],
      thumbnail: get_best_thumbnail(snippet["thumbnails"]),
      default_language: snippet["defaultLanguage"],
      category_id: snippet["categoryId"],
      view_count: String.to_integer(stats["viewCount"] || "0"),
      like_count: String.to_integer(stats["likeCount"] || "0"),
      dislike_count: String.to_integer(stats["dislikeCount"] || "0"),
      favorite_count: String.to_integer(stats["favoriteCount"] || "0"),
      comment_count: String.to_integer(stats["commentCount"] || "0"),
      live_viewer_count: item["liveStreamingDetails"]["concurrentViewers"]
    }
  end

  defp get_best_thumbnail(thumbnails) do
    cond
      thumbnails["maxres"] -> thumbnails["maxres"]["url"]
      thumbnails["high"] -> thumbnails["high"]["url"]
      thumbnails["medium"] -> thumbnails["medium"]["url"]
      true -> thumbnails["default"]["url"]
    end
  end
end
