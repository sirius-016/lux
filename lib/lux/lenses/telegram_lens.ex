defmodule Lux.Lenses.TelegramLens do
  @moduledoc """
  Complete Telegram Bot API Lens for Lux.

  A Lens provides a fluent, composable interface over Lux's HTTP client
  (`Client`) and rate-limiting infrastructure (`RateLimiter`).

  ## Usage

      alias Lux.Lenses.TelegramLens, as: T

      # Without options — uses the default token from config
      T.get_me(config)
      T.send_message(config, chat_id, "Hello!")

      # With override options (per-request token, timeout, etc.)
      T.send_message(config, chat_id, "Hello!", parse_mode: "Markdown")
      T.send_photo(config, chat_id, photo_input, caption: "Look!")

  ## Design Notes

  - Every public function accepts `config :: Lux.Client.Config.t()` as its first
    argument.  The config carries the bot token, default headers, adapter opts, etc.
  - All API calls go through `Client.request/3` so they benefit from retry, logging,
    telemetry, and the configured HTTP adapter (Finch by default).
  - `RateLimiter.run/2` is wrapped around every mutating write call so that burst
    sending does not trigger Telegram's 30 msg/s flood limit.
  - Helper functions (`put_chat_id`, `put_optional`, etc.) live in the private
    section and are the single canonical place where payload maps are assembled.
  - Inline keyboard helpers (`inline_keyboard/1`, `button/3`) return plain maps that
    can be embedded in any send/edit payload.
  - `focus/2` is a tiny combinator — it threads the current state through an
    arbitrary function — useful when building larger pipelines or test fixtures.
  """

  # ---------------------------------------------------------------------------
  # Dependencies
  # ---------------------------------------------------------------------------

  alias Lux.{Client, RateLimiter}

  # ---------------------------------------------------------------------------
  # Compile-time constants
  # ---------------------------------------------------------------------------

  @base_url "https://api.telegram.org"

  # ---------------------------------------------------------------------------
  # Public API — Identity / Bot info
  # ---------------------------------------------------------------------------

  @doc """
  A call to `getMe`.

  Returns basic information about the bot in the form of a `User` object.

  ## Example

      T.get_me(config)
      |> Lux.Client.request()
      #=> {:ok, %{id: 123456789, is_bot: true, first_name: "MyBot", …}}

  """
  @spec get_me(Client.config()) :: Client.result(map())
  def get_me(config) do
    Client.request(config, :get, "/bot#{bot_token(config)}/getMe")
  end

  # ---------------------------------------------------------------------------
  # Public API — Sending messages
  # ---------------------------------------------------------------------------

  @doc """
  A call to `sendMessage`.

  Sends a text message to the given `chat_id`.  All Telegram send options are
  available via the optional keyword list.

  ## Required arguments

  - `chat_id` — integer or binary (`"@channel"` / `"123456789"`)

  ## Optional keys (passed as a keyword list)

  - `:parse_mode`            — `\"HTML\"` | `\"Markdown\"` | `\"MarkdownV2\"`
  - `:disable_web_page_preview`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:allow_sending_without_reply`
  - `:reply_markup`          — a pre-built reply markup map (e.g. from `inline_keyboard/1`)

  ## Example

      T.send_message(config, 123456789, \"Hello *world*!\", parse_mode: \"Markdown\")

  """
  @spec send_message(Client.config(), Client.chat_id(), String.t(), keyword()) ::
          Client.result(map())
  def send_message(config, chat_id, text, opts \\ []) do
    payload =
      %{}
      |> put_chat_id(chat_id)
      |> put_optional(:text, text)
      |> put_parse_mode(opts)
      |> put_optional(:disable_web_page_preview, opts, :disable_web_page_preview)
      |> put_optional(:disable_notification, opts, :disable_notification)
      |> put_optional(:reply_to_message_id, opts, :reply_to_message_id)
      |> put_optional(:allow_sending_without_reply, opts, :allow_sending_without_reply)
      |> put_optional(:reply_markup, opts, :reply_markup)

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/sendMessage", payload)
    end)
  end

  @doc """
  A call to `forwardMessage`.

  Forwards a message from one chat to another without triggering a new
  rate-limit bucket — forwarding is cheap.

  ## Arguments

  - `chat_id`       — destination chat
  - `from_chat_id`  — source chat
  - `message_id`    — message id in the source chat

  """
  @spec forward_message(Client.config(), Client.chat_id(), Client.chat_id(), integer(), keyword()) ::
          Client.result(map())
  def forward_message(config, chat_id, from_chat_id, message_id, opts \\ []) do
    payload =
      %{}
      |> put_chat_id(chat_id)
      |> put_optional(:from_chat_id, from_chat_id)
      |> put_optional(:message_id, message_id)
      |> put_optional(:disable_notification, opts, :disable_notification)

    # Forward is read-like from a rate-limit perspective, but Telegram's
    # flood rules apply to the *destination* chat, so we rate-limit it too.
    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/forwardMessage", payload)
    end)
  end

  # ---------------------------------------------------------------------------
  # Public API — Editing messages
  # ---------------------------------------------------------------------------

  @doc """
  A call to `editMessageText`.

  Edits the text of an inline message or a message sent by the bot.

  The four identification arguments are mutually exclusive:

  - pass `chat_id` + `message_id` for a regular chat message
  - pass only `inline_message_id` for an inline query answer

  ## Optional keys

  - `:parse_mode`
  - `:disable_web_page_preview`
  - `:reply_markup`

  """
  @spec edit_message_text(Client.config(), integer(), integer() | nil, String.t() | nil, keyword()) ::
          Client.result(map())
  def edit_message_text(config, chat_id, message_id, text, opts \\ []) do
    payload =
      %{}
      |> put_message_id(chat_id, message_id)
      |> put_inline_message_id(opts)
      |> put_optional(:text, text)
      |> put_parse_mode(opts)
      |> put_optional(:disable_web_page_preview, opts, :disable_web_page_preview)
      |> put_optional(:reply_markup, opts, :reply_markup)

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/editMessageText", payload)
    end)
  end

  @doc """
  A call to `editMessageCaption`.

  Edits the caption of a message sent by the bot (or an inline message).

  ## Optional keys

  - `:caption`           — new caption text
  - `:parse_mode`
  - `:reply_markup`

  Identification is identical to `edit_message_text/5`.

  """
  @spec edit_message_caption(Client.config(), integer() | nil, integer() | nil, keyword()) ::
          Client.result(map())
  def edit_message_caption(config, chat_id, message_id, opts \\ []) do
    payload =
      %{}
      |> put_message_id(chat_id, message_id)
      |> put_inline_message_id(opts)
      |> put_optional(:caption, opts, :caption)
      |> put_parse_mode(opts)
      |> put_optional(:reply_markup, opts, :reply_markup)

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/editMessageCaption", payload)
    end)
  end

  # ---------------------------------------------------------------------------
  # Public API — Deleting messages
  # ---------------------------------------------------------------------------

  @doc """
  A call to `deleteMessage`.

  Deletes a message.  Note that bots can only delete messages that were sent
  by the bot itself or in a supergroup.

  """
  @spec delete_message(Client.config(), integer()) :: Client.result(boolean())
  def delete_message(config, message_id) do
    payload = %{message_id: message_id}

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/deleteMessage", payload)
    end)
  end

  # ---------------------------------------------------------------------------
  # Public API — Sending media
  # ---------------------------------------------------------------------------

  @doc """
  A call to `sendPhoto`.

  Sends a photo.  `photo` can be a:

  - URL string (`"https://…/photo.jpg"`)
  - local file path (`"/tmp/photo.jpg"` or `"C:\\Photos\\photo.jpg"`)
  - `{:file, file_id}` tuple (an already-uploaded file reference)

  ## Optional keys

  - `:caption`
  - `:parse_mode`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:reply_markup`

  """
  @spec send_photo(Client.config(), Client.chat_id(), Client.input_file(), keyword()) ::
          Client.result(map())
  def send_photo(config, chat_id, photo, opts \\ []) do
    send_media(config, chat_id, "photo", photo, opts)
  end

  @doc """
  A call to `sendDocument`.

  Sends a general file.  Same input conventions as `send_photo/3`.

  ## Optional keys

  - `:caption`
  - `:parse_mode`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:reply_markup`
  - `:thumb`   — thumbnail image (URL, path, or `{:file, id}`)

  """
  @spec send_document(Client.config(), Client.chat_id(), Client.input_file(), keyword()) ::
          Client.result(map())
  def send_document(config, chat_id, document, opts \\ []) do
    send_media(config, chat_id, "document", document, opts)
  end

  @doc """
  A call to `sendVoice`.

  Sends an audio file. Telegram will display it as a voice message.
  Accepts the same inputs as `send_photo/3`.

  ## Optional keys

  - `:caption`
  - `:parse_mode`
  - `:duration`
  - `:performer`
  - `:title`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:reply_markup`

  """
  @spec send_voice(Client.config(), Client.chat_id(), Client.input_file(), keyword()) ::
          Client.result(map())
  def send_voice(config, chat_id, voice, opts \\ []) do
    send_media(config, chat_id, "voice", voice, opts)
  end

  @doc """
  A call to `sendVideo`.

  Sends a video.  Accepts the same inputs as `send_photo/3`.

  ## Optional keys

  - `:caption`
  - `:parse_mode`
  - `:duration`
  - `:width`
  - `:height`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:reply_markup`
  - `:thumb`

  """
  @spec send_video(Client.config(), Client.chat_id(), Client.input_file(), keyword()) ::
          Client.result(map())
  def send_video(config, chat_id, video, opts \\ []) do
    send_media(config, chat_id, "video", video, opts)
  end

  # ---------------------------------------------------------------------------
  # Public API — Chat queries
  # ---------------------------------------------------------------------------

  @doc """
  A call to `getChat`.

  Returns information about a chat.  `chat_id` can be an integer, a username
  (string starting with `@`), or a `channel:` / `group:` link.

  """
  @spec get_chat(Client.config(), Client.chat_id()) :: Client.result(map())
  def get_chat(config, chat_id) do
    payload = put_chat_id(%{}, chat_id)
    Client.request(config, :get, "/bot#{bot_token(config)}/getChat", payload)
  end

  @doc """
  A call to `getChatMemberCount`.

  Returns the number of members in a chat.

  """
  @spec get_chat_member_count(Client.config(), Client.chat_id()) :: Client.result(non_neg_integer())
  def get_chat_member_count(config, chat_id) do
    payload = put_chat_id(%{}, chat_id)
    Client.request(config, :get, "/bot#{bot_token(config)}/getChatMemberCount", payload)
  end

  # ---------------------------------------------------------------------------
  # Public API — Updates (long-polling)
  # ---------------------------------------------------------------------------

  @doc """
  A call to `getUpdates`.

  This is the underlying long-poll driver.  Pass `offset` and `timeout`
  to control the polling loop.  The response contains an array of `Update`
  objects.

  ## Optional keys

  - `:offset`    — pass the last `update_id + 1` to acknowledge processed updates
  - `:limit`     — 1–100 (default 100)
  - `:timeout`   — long-poll timeout in seconds (0–100, default 0)
  - `:allowed_updates` — list of update types to receive

  """
  @spec get_updates(Client.config(), keyword()) :: Client.result([map()])
  def get_updates(config, opts \\ []) do
    payload =
      %{}
      |> maybe_put(:offset, opts, :offset)
      |> maybe_put(:limit, opts, :limit)
      |> maybe_put(:timeout, opts, :timeout)
      |> maybe_put(:allowed_updates, opts, :allowed_updates)

    Client.request(config, :get, "/bot#{bot_token(config)}/getUpdates", payload)
  end

  # ---------------------------------------------------------------------------
  # Public API — Webhook management
  # ---------------------------------------------------------------------------

  @doc """
  A call to `setWebhook`.

  Registers `url` as the webhook endpoint for this bot.  Telegram will then
  push `Update` objects to that URL instead of the bot having to poll.

  ## Optional keys

  - `:certificate`   — an `{:file, path}` tuple pointing at your PEM cert
  - `:max_connections`
  - `:allowed_updates`
  - `:drop_pending_updates`
  - `:secret_token`  — a secret string that will be sent in the
                       `X-Telegram-Bot-Api-Secret-Token` header

  """
  @spec set_webhook(Client.config(), String.t(), keyword()) :: Client.result(boolean())
  def set_webhook(config, url, opts \\ []) do
    payload =
      %{}
      |> put_optional(:url, url)
      |> maybe_put(:certificate, opts, :certificate)
      |> maybe_put(:max_connections, opts, :max_connections)
      |> maybe_put(:allowed_updates, opts, :allowed_updates)
      |> maybe_put(:drop_pending_updates, opts, :drop_pending_updates)
      |> maybe_put(:secret_token, opts, :secret_token)

    Client.request(config, :post, "/bot#{bot_token(config)}/setWebhook", payload)
  end

  @doc """
  A call to `deleteWebhook`.

  Removes the webhook integration.  After this call the bot returns to
  getUpdates-based polling.

  ## Optional keys

  - `:drop_pending_updates` — pass `true` to discard pending updates

  """
  @spec delete_webhook(Client.config(), keyword()) :: Client.result(boolean())
  def delete_webhook(config, opts \\ []) do
    payload = maybe_put(%{}, :drop_pending_updates, opts, :drop_pending_updates)
    Client.request(config, :post, "/bot#{bot_token(config)}/deleteWebhook", payload)
  end

  @doc """
  A call to `getWebhookInfo`.

  Returns current webhook status and debug info.

  """
  @spec get_webhook_info(Client.config()) :: Client.result(map())
  def get_webhook_info(config) do
    Client.request(config, :get, "/bot#{bot_token(config)}/getWebhookInfo")
  end

  # ---------------------------------------------------------------------------
  # Public API — Polls
  # ---------------------------------------------------------------------------

  @doc """
  A call to `sendPoll`.

  Sends a native Telegram poll to the given chat.

  ## Required arguments

  - `chat_id`  — destination chat
  - `question` — poll question text
  - `options`  — list of binary option strings (2–10 options)

  ## Optional keys

  - `:is_anonymous`          — default `true`
  - `:type`                  — `\"regular\"` | `\"quiz\"`
  - `:allows_multiple_answers`
  - `:correct_option_id`     — required when `:type` is `\"quiz\"`
  - `:explanation`
  - `:explanation_parse_mode`
  - `:open_period`           — 5–600 seconds
  - `:close_date`            — Unix timestamp (integer)
  - `:is_closed`
  - `:disable_notification`
  - `:reply_to_message_id`
  - `:reply_markup`

  """
  @spec send_poll(Client.config(), Client.chat_id(), String.t(), [String.t()], keyword()) ::
          Client.result(map())
  def send_poll(config, chat_id, question, options, opts \\ []) when is_list(options) do
    payload =
      %{}
      |> put_chat_id(chat_id)
      |> put_optional(:question, question)
      |> put_optional(:options, options)
      |> put_parse_mode(opts)
      |> maybe_put(:is_anonymous, opts, :is_anonymous)
      |> maybe_put(:type, opts, :type)
      |> maybe_put(:allows_multiple_answers, opts, :allows_multiple_answers)
      |> maybe_put(:correct_option_id, opts, :correct_option_id)
      |> maybe_put(:explanation, opts, :explanation)
      |> maybe_put(:explanation_parse_mode, opts, :explanation_parse_mode)
      |> maybe_put(:open_period, opts, :open_period)
      |> maybe_put(:close_date, opts, :close_date)
      |> maybe_put(:is_closed, opts, :is_closed)
      |> maybe_put(:disable_notification, opts, :disable_notification)
      |> maybe_put(:reply_to_message_id, opts, :reply_to_message_id)
      |> maybe_put(:reply_markup, opts, :reply_markup)

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/sendPoll", payload)
    end)
  end

  @doc """
  A call to `closePoll`.

  Stops a poll previously sent by the bot.

  ## Arguments

  - `chat_id`    — the chat where the poll was sent
  - `message_id` — the original poll message id

  """
  @spec close_poll(Client.config(), integer(), keyword()) :: Client.result(map())
  def close_poll(config, message_id, opts \\ []) do
    payload =
      %{}
      |> put_optional(:chat_id, opts, :chat_id)
      |> put_optional(:message_id, message_id)

    RateLimiter.run(config, fn ->
      Client.request(config, :post, "/bot#{bot_token(config)}/closePoll", payload)
    end)
  end

  # ---------------------------------------------------------------------------
  # Public API — Inline keyboard helpers
  # ---------------------------------------------------------------------------

  @doc """
  Builds an inline keyboard from a list of button rows.

  Each row is a list of `button/3` results.

  ## Example

      keyboard =
        T.inline_keyboard([
          [T.button("Google", url: "https://google.com"),
           T.button("Callback", callback_data: "my_action:do_it")],
          [T.button("Switch inline", switch_inline_query: "search")]
        ])

      T.send_message(config, chat_id, "Pick one:", reply_markup: keyboard)

  """
  @spec inline_keyboard([[map()]]) :: %{inline_keyboard: [[map()]]}
  def inline_keyboard(rows) when is_list(rows) and is_list(hd(rows)) do
    %{inline_keyboard: rows}
  end

  @doc """
  Builds a single inline keyboard button.

  One of the following keyword pairs **must** be provided (or passed as
  positional arguments):

  | key                | description |
  |--------------------|-------------|
  | `:url`             | HTTP/HTTPS URL to open |
  | `:callback_data`   | Data sent back in a `callback_query` |
  | `:switch_inline_query`          | Starts inline query for the current user |
  | `:switch_inline_query_current_chat` | Same but pre-filled with current chat |
  | `:callback_game`   | Launches a game (no data — use with `callback_data` manually) |

  Text is always the first positional argument.

  ## Examples

      button("Click me", callback_data: "myapp:action")
      button("Open", url: "https://example.com")
      button("Search", switch_inline_query: "query")

  """
  @spec button(String.t(), keyword()) :: map()
  def button(text, data \\ []) do
    map = %{text: text}

    case data do
      [url: v]          -> Map.put(map, :url, v)
      [callback_data: v] -> Map.put(map, :callback_data, v)
      [switch_inline_query: v] -> Map.put(map, :switch_inline_query, v)
      [switch_inline_query_current_chat: v] -> Map.put(map, :switch_inline_query_current_chat, v)
      [callback_game: v] -> Map.put(map, :callback_game, v)
      _ -> map
    end
  end

  # ---------------------------------------------------------------------------
  # Public API — Focus (combinator)
  # ---------------------------------------------------------------------------

  @doc """
  Focus threads `state` through an arbitrary function.

  This exists primarily to support pipeline-based testing and composition:

      config
      |> T.focus(& &1)                    # identity
      |> T.send_message(chat_id, "Hi!")   # then send

  In practice, `send_*` functions are called directly, but `focus/2` is useful
  when building fixtures or when a lens needs to be "peeled back" to reveal
  its underlying state.

  """
  @spec focus(Client.config(), (Client.config() -> Client.config())) :: Client.config()
  def focus(config, fun) when is_function(fun, 1) do
    fun.(config)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # put_parse_mode/2
  # ---------------------------------------------------------------------------

  defp put_parse_mode(payload, opts) do
    maybe_put(payload, :parse_mode, opts, :parse_mode)
  end

  # ---------------------------------------------------------------------------
  # put_optional/3 — inject a value from opts into payload when present
  # ---------------------------------------------------------------------------

  defp put_optional(payload, _key, nil), do: payload
  defp put_optional(payload, _key, []),  do: payload

  defp put_optional(payload, key, value) when is_atom(key) do
    Map.put(payload, key, value)
  end

  # Variant that reads from opts keyword list
  defp put_optional(payload, key, opts, opt_key) do
    case Keyword.fetch(opts, opt_key) do
      {:ok, v} -> Map.put(payload, key, v)
      :error   -> payload
    end
  end

  # ---------------------------------------------------------------------------
  # put_chat_id/2
  # ---------------------------------------------------------------------------

  defp put_chat_id(payload, chat_id) when is_binary(chat_id) or is_integer(chat_id) do
    Map.put(payload, :chat_id, chat_id)
  end

  # ---------------------------------------------------------------------------
  # put_message_id/3
  # ---------------------------------------------------------------------------

  # When chat_id is nil the whole block is skipped (inline message path)
  defp put_message_id(payload, nil, _message_id), do: payload

  defp put_message_id(payload, chat_id, message_id) do
    payload
    |> Map.put(:chat_id, chat_id)
    |> Map.put(:message_id, message_id)
  end

  # ---------------------------------------------------------------------------
  # put_inline_message_id/2
  # ---------------------------------------------------------------------------

  defp put_inline_message_id(payload, opts) do
    case Keyword.fetch(opts, :inline_message_id) do
      {:ok, v} -> Map.put(payload, :inline_message_id, v)
      :error   -> payload
    end
  end

  # ---------------------------------------------------------------------------
  # put_media/4 (internal shared helper for send_photo/send_document/etc.)
  # ---------------------------------------------------------------------------

  defp put_media(payload, _key, nil), do: payload
  defp put_media(payload, _key, ""),  do: payload

  defp put_media(payload, key, value) when is_binary(value) do
    Map.put(payload, key, value)
  end

  # ---------------------------------------------------------------------------
  # maybe_put/3 — inject into payload only when the value is truthy and not nil
  # ---------------------------------------------------------------------------

  defp maybe_put(payload, _key, nil) do
    payload
  end

  defp maybe_put(payload, key, opts, opt_key) do
    case Keyword.fetch(opts, opt_key) do
      {:ok, v} when v != nil -> Map.put(payload, key, v)
      _ -> payload
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — shared send_media for photo / document / voice / video
  # ---------------------------------------------------------------------------

  # This module attribute holds the per-method optional keys so that each
  # send_* variant stays DRY.
  @media_optional_keys [
    :caption,
    :parse_mode,
    :duration,
    :width,
    :height,
    :thumb,
    :disable_notification,
    :reply_to_message_id,
    :reply_markup,
    :performer,
    :title
  ]

  defp send_media(config, chat_id, media_type, media, opts) do
    payload =
      %{}
      |> put_chat_id(chat_id)
      |> put_media(String.to_atom(media_type), media)
      |> put_optional(:caption, opts, :caption)
      |> put_parse_mode(opts)
      |> put_optional(:duration, opts, :duration)
      |> put_optional(:width, opts, :width)
      |> put_optional(:height, opts, :height)
      |> put_optional(:thumb, opts, :thumb)
      |> put_optional(:disable_notification, opts, :disable_notification)
      |> put_optional(:reply_to_message_id, opts, :reply_to_message_id)
      |> put_optional(:reply_markup, opts, :reply_markup)
      |> put_optional(:performer, opts, :performer)
      |> put_optional(:title, opts, :title)

    endpoint = "/bot#{bot_token(config)}/send#{String.upcase(media_type)}"

    RateLimiter.run(config, fn ->
      Client.request(config, :post, endpoint, payload)
    end)
  end

  # ---------------------------------------------------------------------------
  # Internal — resolve bot token from config
  # ---------------------------------------------------------------------------

  # Compile-time placeholder — will be replaced by mixcompile-time or runtime
  # resolution once the Lux.Client.Config struct is finalised.
  defp bot_token(%Client.Config{token: token}), do: token
  defp bot_token(_), do: raise("TelegramLens requires a Lux.Client.Config with a :token field")
end
