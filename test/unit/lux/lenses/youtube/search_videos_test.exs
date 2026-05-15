defmodule Lux.Lenses.YouTube.SearchVideosTest do
  use ExUnit.Case, async: true

  describe "after_focus/1" do
    test "normalizes search results" do
      resp = %{"items" => [
        %{"id" => %{"videoId" => "v1"}, "snippet" => %{"channelId" => "ch1",
          "title" => "Search Result", "publishedAt" => "2024-01-01T00:00:00Z",
          "thumbnails" => %{"medium" => %{"url" => "http://img.jpg"}}}}
      ]}

      assert {:ok, %{results: [r], count: 1}} = Lux.Lenses.YouTube.SearchVideos.after_focus(resp)
      assert r.video_id == "v1"
    end
  end
end
