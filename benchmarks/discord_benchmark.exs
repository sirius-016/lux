# Discord Prisms and Lenses Benchmarks
#
# Run with: mix run benchmarks/discord_benchmark.exs

Benchee.run(%{
  "after_focus messages (10)" => fn ->
    messages = Enum.map(1..10, fn i ->
      %{"id" => "#{i}", "channel_id" => "ch1", "content" => "msg #{i}",
        "author" => %{"id" => "u1", "username" => "bot", "discriminator" => "0001"},
        "timestamp" => "2024-01-01T00:00:00Z", "edited_timestamp" => nil,
        "tts" => false, "mention_everyone" => false, "embeds" => [], "reactions" => []}
    end)
    Lux.Lenses.Discord.GetMessages.after_focus(messages)
  end,
  "after_focus messages (50)" => fn ->
    messages = Enum.map(1..50, fn i ->
      %{"id" => "#{i}", "channel_id" => "ch1", "content" => "message #{i}",
        "author" => %{"id" => "u1", "username" => "bot", "discriminator" => "0001"},
        "timestamp" => "2024-01-01T00:00:00Z", "edited_timestamp" => nil,
        "tts" => false, "mention_everyone" => false, "embeds" => [], "reactions" => []}
    end)
    Lux.Lenses.Discord.GetMessages.after_focus(messages)
  end,
  "after_focus channel" => fn ->
    Lux.Lenses.Discord.GetChannel.after_focus(%{
      "id" => "ch1", "name" => "general", "type" => 0, "topic" => "topic",
      "guild_id" => "g1", "position" => 1, "nsfw" => false
    })
  end
}, memory_time: 2, time: 5)
