defmodule Lux.Lenses.Discord.GetChannelTest do
  use ExUnit.Case, async: true

  describe "after_focus/1" do
    test "normalizes channel data" do
      channel = %{"id" => "ch1", "name" => "general", "type" => 0, "topic" => "Main channel",
        "guild_id" => "g1", "position" => 1, "nsfw" => false, "parent_id" => nil,
        "rate_limit_per_user" => 0, "last_message_id" => "m1", "permission_overwrites" => []}

      assert {:ok, ch} = Lux.Lenses.Discord.GetChannel.after_focus(channel)
      assert ch.id == "ch1"
      assert ch.name == "general"
      refute ch.nsfw
    end
  end
end
