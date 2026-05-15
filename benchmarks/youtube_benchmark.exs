# YouTube Lens Benchmarks
Benchee.run(%{
  "normalize video (full)" => fn ->
    item = %{"id" => "v1", "snippet" => %{"title" => "Title", "channelId" => "UC",
      "publishedAt" => "2024-01-01T00:00:00Z", "channelTitle" => "Ch",
      "thumbnails" => %{"high" => %{"url" => "http://x.jpg"}, "default" => %{}},
      "tags" => ["tag1"], "statistics" => %{"viewCount" => "1000", "likeCount" => "50",
      "commentCount" => "10"}, "contentDetails" => %{"duration" => "PT1H"},
      "liveStreamingDetails" => %{"concurrentViewers" => "500"}}
    }
    Lux.Lenses.YouTube.GetVideo.after_focus(%{"items" => [item]})
  end,
  "normalize video list (20 items)" => fn ->
    items = Enum.map(1..20, fn i ->
      %{"id" => "v#{i}", "snippet" => %{"title" => "Video #{i}", "channelId" => "UC",
        "publishedAt" => "2024-01-01T00:00:00Z", "channelTitle" => "Channel",
        "thumbnails" => %{"default" => %{"url" => "http://x/#{i}.jpg"}, "tags" => [],
        "statistics" => %{"viewCount" => "100", "likeCount" => "5", "commentCount" => "0"},
        "contentDetails" => %{}, "liveStreamingDetails" => %{}}
    end)
    Lux.Lenses.YouTube.ListVideos.after_focus(%{
      "items" => items, "pageInfo" => %{"totalResults" => 20, "resultsPerPage" => 20}})
  end,
  "normalize search results (10 items)" => fn ->
    items = Enum.map(1..10, fn i ->
      %{"id" => %{"videoId" => "v#{i}"}, "snippet" => %{"title" => "Result #{i}",
        "channelId" => "UC", "publishedAt" => "2024-01-01T00:00:00Z",
        "thumbnails" => %{"medium" => %{"url" => "http://x.jpg"}}}}
    end)
    Lux.Lenses.YouTube.SearchVideos.after_focus(%{"items" => items})
  end
}, memory_time: 2, time: 5)
