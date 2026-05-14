defmodule Lux.Lenses.TelegramLens.Client do
  @moduledoc """
  HTTP client for the Telegram Bot API.

  Handles all HTTP requests to the Telegram API with:
  - Exponential backoff retry on transient failures
  - Rate-limit awareness (429 with retry_after)
  - Comprehensive error mapping
  - Token management from config or environment
  """

  @endpoint "https://api.telegram.org/bot"
  @retryable_statuses [429, 500, 502, 503, 504]
  @max_retries 3

  @type method :: String.t()
  @type params :: map()
  @type opts :: keyword()
  @type result :: {:ok, term()} | {:error, term()}

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @doc """
  Make a request to the Telegram Bot API.

  ## Parameters
  - `method`: The Telegram API method name (e.g., "sendMessage")
  - `params`: Map of parameters for the method
  - `opts`: Keyword list of options

  ## Options
  - `:token` - Bot token (defaults to config/env)
  - `:max_retries` - Maximum retry attempts (default 3)
  - `:test_mode` - Use test servers (default false)

  ## Returns
  `{:ok, result}` or `{:error, reason}`
  """
  @spec request(method(), params(), opts()) :: result()
  def request(method, params \\ %{}, opts \\ []) do
    token = resolve_token(opts)
    max_retries = Keyword.get(opts, :max_retries, @max_retries)

    if is_nil(token) or token == "" do
      {:error, "Telegram bot token not found. Set TELEGRAM_BOT_TOKEN or configure :lux, :telegram_token"}
    else
      url = build_url(token, method, opts)
      do_request(method, url, params, max_retries, 0)
    end
  end

  @doc """
  Make a multipart request (for file uploads).

  Same as `request/3` but uses multipart/form-data encoding.
  """
  @spec request_multipart(method(), params(), opts()) :: result()
  def request_multipart(method, params \\ %{}, opts \\ []) do
    token = resolve_token(opts)
    max_retries = Keyword.get(opts, :max_retries, @max_retries)

    if is_nil(token) or token == "" do
      {:error, "Telegram bot token not found"}
    else
      url = build_url(token, method, opts)
      do_multipart_request(url, params, max_retries, 0)
    end
  end

  # --------------------------------------------------------------------------
  # Private
  # --------------------------------------------------------------------------

  defp resolve_token(opts) do
    case Keyword.get(opts, :token) do
      nil ->
        Application.get_env(:lux, :telegram_token) ||
          System.get_env("TELEGRAM_BOT_TOKEN")
      token ->
        token
    end
  end

  defp build_url(token, method, opts) do
    test_mode = Keyword.get(opts, :test_mode, false)
    base = if test_mode, do: "https://api.telegram.org/bot", else: @endpoint
    "#{base}#{token}/#{method}"
  end

  defp do_request(_method, url, params, max_retries, attempt) do
    json_body = Jason.encode!(params)

    Req.post(url, json: params)
    |> process_response(url, params, max_retries, attempt)
  end

  defp do_multipart_request(url, params, max_retries, attempt) do
    # Handle file uploads via multipart
    multipart = build_multipart(params)

    Req.post(url, body: multipart)
    |> process_response(url, params, max_retries, attempt)
  end

  defp build_multipart(params) do
    # Build multipart body for file uploads
    multipart_parts = for {key, value} <- params do
      case value do
        %{path: path} ->
          {:file, path, key, []}
        %{file_id: file_id} ->
          {:file, {:form, file_id}, key, [{"content-type", "application/octet-stream"}]}
        _ ->
          {:multipart, [{key, value}]}
      end
    end
    {:multipart, multipart_parts}
  end

  defp process_response({:ok, %{status: 200, body: %{"ok" => true, "result" => result}}}, _url, _params, _max_retries, _attempt) do
    {:ok, result}
  end

  defp process_response({:ok, %{status: 429, body: %{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}}}}, url, params, max_retries, attempt) do
    if attempt < max_retries do
      Logger.warning("Telegram rate limited. Retrying after #{retry_after}s")
      :timer.sleep(retry_after * 1000)
      do_request("retry", url, params, max_retries, attempt + 1)
    else
      {:error, :rate_limited}
    end
  end

  defp process_response({:ok, %{status: status, body: %{"ok" => false, "description" => desc, "error_code" => code}}}, _url, _params, _max_retries, _attempt) do
    {:error, {:telegram_error, code, desc}}
  end

  defp process_response({:ok, %{status: status}}, _url, _params, max_retries, attempt) when status in @retryable_statuses do
    if attempt < max_retries do
      backoff = trunc(:math.pow(2, attempt) * 500)
      Logger.warning("Telegram API error #{status}. Retrying in #{backoff}ms (attempt #{attempt + 1}/#{max_retries})")
      :timer.sleep(backoff)
      do_request("retry", "", %{}, max_retries, attempt + 1)
    else
      {:error, {:api_error, status}}
    end
  end

  defp process_response({:error, %{reason: %{__struct__: Tesla.TransportError, message: msg}}}, _url, _params, max_retries, attempt) do
    if attempt < max_retries do
      backoff = trunc(:math.pow(2, attempt) * 1000)
      Logger.warning("Network error: #{msg}. Retrying in #{backoff}ms")
      :timer.sleep(backoff)
      do_request("retry", "", %{}, max_retries, attempt + 1)
    else
      {:error, {:network_error, msg}}
    end
  end

  defp process_response({:error, reason}, _url, _params, _max_retries, _attempt) do
    {:error, reason}
  end

  defp process_response(other, _url, _params, _max_retries, _attempt) do
    {:error, {:unexpected_response, inspect(other)}}
  end
end
