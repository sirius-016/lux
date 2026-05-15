defmodule Lux.Lenses.YouTube.ListVideosTest do
  use ExUnit.Case, async: true

  describe "after_focus/1" do
    test "normalizes video list response" do
      response = %{
        "items" => [
          %{"id" => "dQw4w9WgXcQ", "snippet" => %{"title" => "Test Video", "channelId" => "UC",
            "publishedAt" => "2024-01-01T00:00:00Z", "channelTitle" => "Test",
            "thumbnails" => %{"default" => %{"url" => "http://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg"},
            "tags" => ["test"]}, "statistics" => %{"viewCount" => "100", "likeCount" => "5"},
            "contentDetails" => %{"duration" => "PT4M12S"}, "liveStreamingDetails" => %{}}
        ],
        "pageInfo" => %{"totalResults" => 1, "resultsPerPage" => 1}
      }

      assert {:ok, %{videos: [v], total: 1}} = Lux.Lenses.YouTube.ListVideos.after_focus(response)
      assert v.id == "dQw4w9WgXcQ"
      assert v.title == "Test Video"
      assert v.view_count == 100
    end

    test "handles empty response" do
      assert {:ok, %{videos: [], total: 0}} = Lux.Lenses.YouTube.ListVideos.after_focus(%{
        "items" => [], "pageInfo" => %{"totalResults" => 0, "resultsPerPage" => 0}})
    end

    test "handles error response" do
      assert {:error, _} = Lux.Lenses.YouTube.ListVideos.after_focus(%{"error" => %{"message" => "API Error"}})
    end
  end
end
