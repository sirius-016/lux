defmodule Lux.Lenses.YouTube.GetVideoTest do
  use ExUnit.Case, async: true

  describe "after_focus/1" do
    test "normalizes single video" do
      item = %{"id" => "vid1", "snippet" => %{"title" => "My Video"},
        "statistics" => %{"viewCount" => "1000"}}

      assert {:ok, v} = Lux.Lenses.YouTube.GetVideo.after_focus(%{"items" => [item]})
      assert v.title == "My Video"
    end

    test "handles not found" do
      assert {:error, "Video not found"} = Lux.Lenses.YouTube.GetVideo.after_focus(%{"items" => []})
    end
  end
end
