defmodule Lux.Lenses.Discord.GetMessagesTest do
  use ExUnit.Case, async: true

  describe "after_focus/1" do
    test "normalizes a list of messages" do
      messages = [
        %{"id" => "1", "channel_id" => "ch1", "content" => "Hello",
          "author" => %{"id" => "u1", "username" => "bot", "discriminator" => "0001"},
          "timestamp" => "2024-01-01T00:00:00Z", "edited_timestamp" => nil,
          "tts" => false, "mention_everyone" => false, "embeds" => [], "reactions" => []}
      ]

      assert {:ok, %{messages: [msg], count: 1}} = Lux.Lenses.Discord.GetMessages.after_focus(messages)
      assert msg.id == "1"
      assert msg.content == "Hello"
      assert msg.author.username == "bot"
    end

    test "handles error responses" do
      assert {:error, _} = Lux.Lenses.Discord.GetMessages.after_focus(%{"code" => 10013, "message" => "Unknown"})
    end
  end
end
