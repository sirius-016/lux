defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 with OAuth 2.0 bearer token support,
  rate limit handling, and exponential backoff retry logic.

  All API requests are routed through this client to ensure consistent
  authentication, error handling, and rate limit compliance.
  """

  alias Lux.Integrations.Twitter.RateLimiter

  @endpoint "https://api.twitter.com/2"
  @max_retries 3
  @base_backoff_ms 1000

  @doc """
  Makes an authenticated request to the Twitter API v2.

  ## Parameters

    - `method` - HTTP method (:get, :post, :delete, :put, :patch)
    - `path` - API path (e.g., "/tweets", "/users/:id/followers")
    - `opts` - Options map including:
      - `:token` - Override bearer token
      - `:json` - JSON body for POST/PUT requests
      - `:params` - Query parameters
      - `:headers` - Additional headers
      - `:max_retries` - Override max retry count

  ## Returns

    - `{:ok, body}` - Successful response with decoded JSON body
    - `{:error, {:rate_limited, errors}}` - Rate limited (429)
    - `{:error, {status, errors}}` - HTTP error with status code
    - `{:error, term()}` - Network or other error
  """
  @spec request(atom(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || get_token()
    max_retries = opts[:max_retries] || @max_retries

    # Wait for rate limiter clearance
    endpoint_key = endpoint_key(method, path)
    RateLimiter.wait(endpoint_key)

    do_request(method, path, token, opts, max_retries, 0)
  end

  @spec do_request(atom(), String.t(), String.t(), map(), non_neg_integer(), non_neg_integer()) ::
          {:ok, map()} | {:error, term()}
  defp do_request(method, path, token, opts, max_retries, attempt) do
    url = build_url(path, opts[:params])
    headers = build_headers(token, opts[:headers])
    body = opts[:json]

    request_opts = [
      method: method,
      url: url,
      headers: headers
    ]

    request_opts = if body, do: Keyword.put(request_opts, :json, body), else: request_opts

    request_opts
    |> Req.new()
    |> Req.request()
    |> handle_response(path)
    |> maybe_retry(method, path, token, opts, max_retries, attempt)
  end

  @spec handle_response({:ok, Req.Response.t()} | {:error, term()}, String.t()) ::
          {:ok, map()} | {:error, term()} | {:retry, term()}
  defp handle_response({:ok, %{status: status, headers: resp_headers} = resp}, path)
       when status in 200..299 do
    # Update rate limiter from response headers
    update_rate_limits(path, resp_headers)
    {:ok, resp.body}
  end

  defp handle_response({:ok, %{status: 429, headers: resp_headers, body: body}}, path) do
    update_rate_limits(path, resp_headers)
    reset_time = get_rate_limit_reset(resp_headers)
    {:retry, {:rate_limited, reset_time, body}}
  end

  defp handle_response({:ok, %{status: status, body: %{"errors" => errors}}}, _path) do
    {:error, {status, errors}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _path) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}, _path) do
    {:retry, error}
  end

  @spec maybe_retry(
          {:ok, map()} | {:error, term()} | {:retry, term()},
          atom(),
          String.t(),
          String.t(),
          map(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, map()} | {:error, term()}
  defp maybe_retry({:ok, body}, _, _, _, _, _), do: {:ok, body}

  defp maybe_retry({:error, reason}, _, _, _, _, _), do: {:error, reason}

  defp maybe_retry({:retry, {:rate_limited, reset_time, body}}, _, _, _, max_retries, attempt)
       when attempt < max_retries do
    backoff = calculate_backoff(attempt, reset_time)
    Process.sleep(backoff)
    do_request(:get, "", "", %{}, max_retries, attempt + 1)
  end

  defp maybe_retry({:retry, {:rate_limited, _reset_time, body}}, _, _, _, _, _) do
    {:error, {:rate_limited, body}}
  end

  defp maybe_retry({:retry, _reason}, method, path, token, opts, max_retries, attempt)
       when attempt < max_retries do
    backoff = calculate_backoff(attempt, nil)
    Process.sleep(backoff)
    do_request(method, path, token, opts, max_retries, attempt + 1)
  end

  defp maybe_retry({:retry, reason}, _, _, _, _, _), do: {:error, reason}

  @spec get_token() :: String.t() | nil
  defp get_token do
    Application.get_env(:lux, :api_keys)[:twitter] ||
      System.get_env("TWITTER_BEARER_TOKEN")
  end

  @spec build_url(String.t(), map() | nil) :: String.t()
  defp build_url(path, nil), do: @endpoint <> path

  defp build_url(path, params) when map_size(params) == 0, do: @endpoint <> path

  defp build_url(path, params) do
    query = URI.encode_query(params)
    @endpoint <> path <> "?" <> query
  end

  @spec build_headers(String.t() | nil, [{String.t(), String.t()}] | nil) ::
          [{String.t(), String.t()}]
  defp build_headers(token, extra_headers) do
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "LuxTwitterClient/1.0"}
    ]

    if extra_headers, do: headers ++ extra_headers, else: headers
  end

  @spec calculate_backoff(non_neg_integer(), integer() | nil) :: non_neg_integer()
  defp calculate_backoff(attempt, nil) do
    # Exponential backoff with jitter
    base = @base_backoff_ms * :math.pow(2, attempt) |> trunc()
    jitter = :rand.uniform(500)
    base + jitter
  end

  defp calculate_backoff(_attempt, reset_time) when is_integer(reset_time) and reset_time > 0 do
    # Wait until rate limit resets, capped at 60 seconds
    now = System.system_time(:second)
    wait_secs = max(reset_time - now, 0)
    min(wait_secs * 1000, 60_000)
  end

  defp calculate_backoff(attempt, _), do: calculate_backoff(attempt, nil)

  @spec endpoint_key(atom(), String.t()) :: String.t()
  defp endpoint_key(method, path) do
    "#{method}:#{path}"
  end

  @spec update_rate_limits(String.t(), [{String.t(), String.t()}]) :: :ok
  defp update_rate_limits(path, headers) do
    remaining = get_header_value(headers, "x-rate-limit-remaining")
    reset = get_header_value(headers, "x-rate-limit-reset")

    if remaining && reset do
      {remaining_int, _} = Integer.parse(remaining)
      {reset_int, _} = Integer.parse(reset)
      RateLimiter.update_limits(path, remaining_int, reset_int)
    end

    :ok
  end

  @spec get_rate_limit_reset([{String.t(), String.t()}]) :: integer() | nil
  defp get_rate_limit_reset(headers) do
    case get_header_value(headers, "x-rate-limit-reset") do
      nil -> nil
      val -> String.to_integer(val)
    end
  end

  @spec get_header_value([{String.t(), String.t()}], String.t()) :: String.t() | nil
  defp get_header_value(headers, key) do
    case Enum.find(headers, fn {k, _} -> String.downcase(k) == String.downcase(key) end) do
      {_, value} -> value
      nil -> nil
    end
  end
end
