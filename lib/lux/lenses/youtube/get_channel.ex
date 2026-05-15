defmodule Lux.Lenses.YouTube.GetChannel do
  @moduledoc "Get information about a YouTube channel."
  use Lux.Lens,
    name: "YouTube Get Channel",
    description: "Retrieves information about a YouTube channel.",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID (starts with UC...)"},
        for_username: %{type: :string, description: "Username (for Handle)"},
        mine: %{type: :boolean, description: "Get authenticated user's channel"},
        part: %{type: :string, description: "Comma-separated parts", default: "snippet,statistics,contentDetails"}
      }
    }

  @impl true
  def before_focus(params) do
    p = %{"part" => params["part"] || "snippet,statistics,contentDetails"}
    p = cond do
      params["channel_id"] -> Map.put(p, "id", params["channel_id"])
      params["for_username"] -> Map.put(p, "forUsername", params["for_username"])
      params["mine"] -> Map.put(p, "mine", "true")
      true -> p
    end
    %{"url" => "https://www.googleapis.com/youtube/v3/channels", "params" => p}
  end

  @impl true
  def after_focus(%{"items" => [item | _]}) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}
    content = item["contentDetails"] || %{}
    {:ok, %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      thumbnail: snippet["thumbnails"]["high"]["url"],
      country: snippet["country"],
      view_count: String.to_integer(stats["viewCount"] || "0"),
      subscriber_count: String.to_integer(stats["subscriberCount"] || "0"),
      video_count: String.to_integer(stats["videoCount"] || "0"),
      hidden_subscriber_count: stats["hiddenSubscriberCount"],
      uploads_playlist_id: content["relatedPlaylists"]["uploads"]
    }}
  end

  def after_focus(%{"items" => []}), do: {:error, "Channel not found"}
  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}
end
