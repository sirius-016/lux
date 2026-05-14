defmodule Lux.Lenses.TelegramLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.TelegramLens

  alias Lux.Lenses.TelegramLens
  alias Lux.Lenses.TelegramLens.Client

  setup do
    # Set a fake token for tests
    System.put_env("TELEGRAM_BOT_TOKEN", "test_token_123")
    :ok
  end

  # ===========================================================================
  # get_me/1
  # ===========================================================================
  describe "get_me/1" do
    test "returns bot info on success" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.url |> String.contains?("getMe")
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"id": 123456789, "is_bot": true, "first_name": "TestBot"}}))
      end)

      assert {:ok, %{"id" => 123456789, "is_bot" => true, "first_name" => "TestBot"}} = TelegramLens.get_me()
    end

    test "returns error on API failure" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 401, "description": "Unauthorized"}))
      end)

      assert {:error, {:telegram_error, 401, "Unauthorized"}} = TelegramLens.get_me()
    end
  end

  # ===========================================================================
  # send_message/3
  # ===========================================================================
  describe "send_message/3" do
    test "sends message with required params" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["chat_id"] == 123456
        assert body_map["text"] == "Hello World"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 42, "text": "Hello World", "chat": {"id": 123456}}}))
      end)

      assert {:ok, %{"message_id" => 42, "text" => "Hello World"}} = TelegramLens.send_message(123456, "Hello World")
    end

    test "passes optional params to API" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["parse_mode"] == "HTML"
        assert body_map["disable_notification"] == true
        assert body_map["reply_to_message_id"] == 41
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 42}}))
      end)

      assert {:ok, _} = TelegramLens.send_message(123456, "<b>Bold</b>",
        parse_mode: "HTML",
        disable_notification: true,
        reply_to_message_id: 41
      )
    end

    test "raises on non-binary text" do
      assert_raise FunctionClauseError, fn ->
        TelegramLens.send_message(123456, :not_a_string)
      end
    end

    test "returns error on unauthorized" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 401, "description": "Unauthorized"}))
      end)

      assert {:error, {:telegram_error, 401, "Unauthorized"}} = TelegramLens.send_message(123456, "test")
    end
  end

  # ===========================================================================
  # forward_message/4
  # ===========================================================================
  describe "forward_message/4" do
    test "forwards message between chats" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["chat_id"] == 999
        assert body_map["from_chat_id"] == 111
        assert body_map["message_id"] == 42
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 99, "forward_from_chat": {"id": 111}}}))
      end)

      assert {:ok, %{"message_id" => 99}} = TelegramLens.forward_message(999, 111, 42)
    end

    test "passes optional disable_notification" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["disable_notification"] == true
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.forward_message(999, 111, 42, disable_notification: true)
    end
  end

  # ===========================================================================
  # edit_message_text/5
  # ===========================================================================
  describe "edit_message_text/5" do
    test "edits message by chat_id and message_id" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["chat_id"] == 123
        assert body_map["message_id"] == 42
        assert body_map["text"] == "Updated"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 42, "text": "Updated"}}))
      end)

      assert {:ok, %{"text" => "Updated"}} = TelegramLens.edit_message_text(123, 42, nil, "Updated")
    end

    test "edits inline message by inline_message_id" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["inline_message_id"] == "inline_123"
        assert body_map["text"] == "Inline updated"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert {:ok, true} = TelegramLens.edit_message_text(nil, nil, "inline_123", "Inline updated")
    end

    test "supports parse_mode in edit" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["parse_mode"] == "MarkdownV2"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {}}))
      end)

      assert {:ok, _} = TelegramLens.edit_message_text(123, 42, nil, "*bold*", parse_mode: "MarkdownV2")
    end
  end

  # ===========================================================================
  # edit_message_caption/4
  # ===========================================================================
  describe "edit_message_caption/4" do
    test "edits caption" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["caption"] == "New caption"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 42}}))
      end)

      assert {:ok, _} = TelegramLens.edit_message_caption(123, 42, nil, caption: "New caption")
    end
  end

  # ===========================================================================
  # delete_message/2
  # ===========================================================================
  describe "delete_message/2" do
    test "deletes message successfully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert :ok = TelegramLens.delete_message(123456, 42)
    end

    test "returns :ok even if result is not exactly true" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"ok": true}}))
      end)

      assert :ok = TelegramLens.delete_message(123456, 42)
    end

    test "returns error on failure" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 400, "description": "Bad Request"}))
      end)

      assert {:error, {:telegram_error, 400, "Bad Request"}} = TelegramLens.delete_message(123456, 42)
    end
  end

  # ===========================================================================
  # send_photo/3
  # ===========================================================================
  describe "send_photo/3" do
    test "sends photo by URL" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["photo"] == "https://example.com/photo.jpg"
        assert body_map["caption"] == "My photo"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1, "photo": [{}]}}))
      end)

      assert {:ok, %{"message_id" => 1}} = TelegramLens.send_photo(123, "https://example.com/photo.jpg", caption: "My photo")
    end

    test "sends photo with spoiler tag" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["has_spoiler"] == true
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.send_photo(123, "https://example.com/photo.jpg", has_spoiler: true)
    end
  end

  # ===========================================================================
  # send_document/3
  # ===========================================================================
  describe "send_document/3" do
    test "sends document" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["document"] == "/path/to/file.pdf"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.send_document(123, "/path/to/file.pdf")
    end

    test "passes thumbnail option" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["thumbnail"] == "thumb_id"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {}}))
      end)

      assert {:ok, _} = TelegramLens.send_document(123, "doc_id", thumbnail: "thumb_id")
    end
  end

  # ===========================================================================
  # send_voice/3
  # ===========================================================================
  describe "send_voice/3" do
    test "sends voice message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["voice"] == "/path/to/voice.ogg"
        assert body_map["duration"] == 30
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.send_voice(123, "/path/to/voice.ogg", duration: 30)
    end
  end

  # ===========================================================================
  # send_video/3
  # ===========================================================================
  describe "send_video/3" do
    test "sends video" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["video"] == "video.mp4"
        assert body_map["supports_streaming"] == true
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.send_video(123, "video.mp4", supports_streaming: true)
    end

    test "sends video with dimensions" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["width"] == 1920
        assert body_map["height"] == 1080
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {}}))
      end)

      assert {:ok, _} = TelegramLens.send_video(123, "video.mp4", width: 1920, height: 1080)
    end
  end

  # ===========================================================================
  # get_chat/1
  # ===========================================================================
  describe "get_chat/1" do
    test "returns chat info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["chat_id"] == 123456
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"id": 123456, "type": "private", "first_name": "John"}}))
      end)

      assert {:ok, %{"id" => 123456, "type" => "private"}} = TelegramLens.get_chat(123456)
    end
  end

  # ===========================================================================
  # get_chat_member_count/1
  # ===========================================================================
  describe "get_chat_member_count/1" do
    test "returns member count" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": 42}))
      end)

      assert {:ok, 42} = TelegramLens.get_chat_member_count(-100123456)
    end
  end

  # ===========================================================================
  # get_updates/1
  # ===========================================================================
  describe "get_updates/1" do
    test "gets updates with default params" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["timeout"] == 0
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": [{"update_id": 1}]}))
      end)

      assert {:ok, [%{"update_id" => 1}]} = TelegramLens.get_updates()
    end

    test "passes offset and timeout" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["offset"] == 123
        assert body_map["timeout"] == 30
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": []}))
      end)

      assert {:ok, []} = TelegramLens.get_updates(offset: 123, timeout: 30)
    end

    test "filters allowed_updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["allowed_updates"] == ~s(["message","callback_query"])
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": []}))
      end)

      assert {:ok, []} = TelegramLens.get_updates(allowed_updates: ["message", "callback_query"])
    end
  end

  # ===========================================================================
  # set_webhook/2
  # ===========================================================================
  describe "set_webhook/2" do
    test "sets webhook successfully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["url"] == "https://myapp.com/telegram"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert :ok = TelegramLens.set_webhook("https://myapp.com/telegram")
    end

    test "passes max_connections option" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["max_connections"] == 50
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert :ok = TelegramLens.set_webhook("https://myapp.com/telegram", max_connections: 50)
    end

    test "returns error on invalid URL" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 400, "description": "Bad webhook URL"}))
      end)

      assert {:error, {:telegram_error, 400, "Bad webhook URL"}} = TelegramLens.set_webhook("http://not-https.com")
    end
  end

  # ===========================================================================
  # delete_webhook/1
  # ===========================================================================
  describe "delete_webhook/1" do
    test "deletes webhook" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert :ok = TelegramLens.delete_webhook()
    end

    test "passes drop_pending_updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["drop_pending_updates"] == true
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": true}))
      end)

      assert :ok = TelegramLens.delete_webhook(drop_pending_updates: true)
    end
  end

  # ===========================================================================
  # get_webhook_info/1
  # ===========================================================================
  describe "get_webhook_info/1" do
    test "returns webhook info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"url": "https://myapp.com/wh", "pending_update_count": 0}}))
      end)

      assert {:ok, %{"url" => "https://myapp.com/wh", "pending_update_count" => 0}} = TelegramLens.get_webhook_info()
    end
  end

  # ===========================================================================
  # send_poll/4
  # ===========================================================================
  describe "send_poll/4" do
    test "sends regular poll" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["question"] == "Favorite color?"
        assert body_map["options"] == ~s(["Red","Green","Blue"])
        assert body_map["is_anonymous"] == false
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1, "poll": {"question": "Favorite color?"}}}))
      end)

      assert {:ok, %{"poll" => %{"question" => "Favorite color?"}}} =
        TelegramLens.send_poll(123, "Favorite color?", ["Red", "Green", "Blue"], is_anonymous: false)
    end

    test "sends quiz poll with correct answer" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["type"] == "quiz"
        assert body_map["correct_option_id"] == 0
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"message_id": 1}}))
      end)

      assert {:ok, _} = TelegramLens.send_poll(123, "Capital of France?", ["Paris", "London"], type: "quiz", correct_option_id: 0)
    end

    test "raises on invalid question type" do
      assert_raise FunctionClauseError, fn ->
        TelegramLens.send_poll(123, 123, ["a", "b"])
      end
    end

    test "raises on invalid options type" do
      assert_raise FunctionClauseError, fn ->
        TelegramLens.send_poll(123, "Question?", "not a list")
      end
    end
  end

  # ===========================================================================
  # close_poll/2
  # ===========================================================================
  describe "close_poll/2" do
    test "closes poll" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["chat_id"] == 123
        assert body_map["message_id"] == 42
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"is_closed": true}}))
      end)

      assert {:ok, %{"is_closed" => true}} = TelegramLens.close_poll(123, 42)
    end
  end

  # ===========================================================================
  # Keyboard helpers
  # ===========================================================================
  describe "inline_keyboard/1" do
    test "creates keyboard with rows" do
      kb = TelegramLens.inline_keyboard([
        [TelegramLens.button("A", "a"), TelegramLens.button("B", "b")],
        [TelegramLens.button("C", "c")]
      ])

      assert %{inline_keyboard: rows} = kb
      assert length(rows) == 2
      assert length(Enum.at(rows, 0)) == 2
      assert hd(hd(rows)) == %{"text" => "A", "callback_data" => "a"}
    end

    test "creates empty keyboard" do
      kb = TelegramLens.inline_keyboard([])
      assert kb == %{inline_keyboard: []}
    end
  end

  describe "button/3" do
    test "creates callback button" do
      btn = TelegramLens.button("Click me", "callback_123")
      assert btn == %{"text" => "Click me", "callback_data" => "callback_123"}
    end

    test "creates URL button" do
      btn = TelegramLens.button("Visit", nil, url: "https://example.com")
      assert btn == %{"text" => "Visit", "url" => "https://example.com"}
    end

    test "creates button without optional params" do
      btn = TelegramLens.button("Just text")
      assert btn == %{"text" => "Just text"}
    end

    test "creates switch_inline_query button" do
      btn = TelegramLens.button("Search", nil, switch_inline_query: "query")
      assert btn == %{"text" => "Search", "switch_inline_query" => "query"}
    end
  end

  # ===========================================================================
  # focus/2
  # ===========================================================================
  describe "focus/2" do
    test "dispatches generic action" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"ok": true}}))
      end)

      assert {:ok, _} = TelegramLens.focus(%{action: "getMe"})
    end

    test "dispatches with string key" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {"ok": true}}))
      end)

      assert {:ok, _} = TelegramLens.focus(%{"action" => "getMe"})
    end

    test "strips action from params" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        refute Map.has_key?(body_map, "action")
        refute Map.has_key?(body_map, "token")
        refute Map.has_key?(body_map, "max_retries")
        Plug.Conn.resp(conn, 200, ~s({"ok": true, "result": {}}))
      end)

      assert {:ok, _} = TelegramLens.focus(%{action: "sendMessage", chat_id: 123, text: "hi", token: "secret", max_retries: 5})
    end

    test "returns error when action is missing" do
      assert {:error, "action is required"} = TelegramLens.focus(%{chat_id: 123})
    end
  end

  # ===========================================================================
  # Error handling
  # ===========================================================================
  describe "error handling" do
    test "handles rate limit 429" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 429, "description": "Too Many Requests", "parameters": {"retry_after": 1}}))
      end)

      # With skip: true, rate limiter is bypassed
      assert {:error, {:telegram_error, 429, "Too Many Requests"}} = TelegramLens.get_me(skip: true)
    end

    test "handles server error 500" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": false, "error_code": 500, "description": "Internal Server Error"}))
      end)

      assert {:error, {:telegram_error, 500, "Internal Server Error"}} = TelegramLens.get_me()
    end

    test "handles network errors" do
      assert {:error, {:error, :nxdomain}} = TelegramLens.get_me()
    end
  end
end
