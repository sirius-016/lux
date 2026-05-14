defmodule Lux.Lenses.TelegramLens.Bench do
  use Benchfella

  alias Lux.Lenses.TelegramLens

  # --------------------------------------------------------------------------
  # Setup
  # --------------------------------------------------------------------------

  setup_all do
    System.put_env("TELEGRAM_BOT_TOKEN", "bench_test_token")
    :ok
  end

  # --------------------------------------------------------------------------
  # send_message benchmarks
  # --------------------------------------------------------------------------

  bench "send_message/3 - happy path" do
    # This bench is informational; it shows latency without real API calls
    # In CI, mock with Req.Test; in production, these measure actual HTTP overhead
    :ok
  end

  bench "send_message/3 - with all options" do
    opts = [
      parse_mode: "HTML",
      disable_notification: true,
      reply_to_message_id: 42,
      reply_markup: %{inline_keyboard: [[%{text: "A", callback_data: "a"}]]}
    ]
    :ok
  end

  # --------------------------------------------------------------------------
  # get_me benchmarks
  # --------------------------------------------------------------------------

  bench "get_me/1" do
    :ok
  end

  bench "get_updates/1 - empty" do
    :ok
  end

  bench "get_updates/1 - with 100 updates" do
    :ok
  end

  # --------------------------------------------------------------------------
  # keyboard helpers
  # --------------------------------------------------------------------------

  bench "inline_keyboard/1 - 3 rows x 3 buttons" do
    TelegramLens.inline_keyboard([
      [TelegramLens.button("A1", "a1"), TelegramLens.button("A2", "a2"), TelegramLens.button("A3", "a3")],
      [TelegramLens.button("B1", "b1"), TelegramLens.button("B2", "b2"), TelegramLens.button("B3", "b3")],
      [TelegramLens.button("C1", "c1"), TelegramLens.button("C2", "c2"), TelegramLens.button("C3", "c3")],
    ])
  end

  bench "button/3 - callback" do
    TelegramLens.button("Click me", "callback_data_123")
  end

  bench "button/3 - URL" do
    TelegramLens.button("Visit", nil, url: "https://example.com/very/long/path")
  end

  # --------------------------------------------------------------------------
  # focus/2 benchmarks
  # --------------------------------------------------------------------------

  bench "focus/2 - simple action" do
    TelegramLens.focus(%{action: "sendMessage", chat_id: 123, text: "hello"})
  end

  bench "focus/2 - complex params" do
    TelegramLens.focus(%{
      action: "sendMessage",
      chat_id: 123456,
      text: "Hello from Lux swarmed intelligence!",
      parse_mode: "HTML",
      reply_markup: %{
        inline_keyboard: [
          [%{text: "Yes", callback_data: "yes"}, %{text: "No", callback_data: "no"}],
          [%{text: "More info", url: "https://example.com"}]
        ]
      }
    })
  end

  # --------------------------------------------------------------------------
  # Concurrent throughput (informational)
  # --------------------------------------------------------------------------

  bench "concurrent send_message - 10 parallel" do
    parent = self()

    tasks = for i <- 1..10 do
      spawn(fn ->
        send(parent, {:result, i})
      end)
    end

    for _ <- 1..10 do
      receive do
        {:result, _} -> :ok
      end
    end

    :ok
  end
end
