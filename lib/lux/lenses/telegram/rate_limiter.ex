defmodule Lux.Lenses.TelegramLens.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for the Telegram Bot API.

  Telegram limits bots to ~30 messages per second globally.
  This module implements a token bucket algorithm to manage request
  quotas and queue requests when the rate limit is approached.

  ## Usage

      RateLimiter.run([], fn -> Client.request("sendMessage", params, []) end)

  ## Configuration

  - `:bucket_size` - Maximum tokens in the bucket (default 30)
  - `:refill_rate` - Tokens added per second (default 30)
  - `:refill_interval` - Refill interval in ms (default 1000)
  - `:queue_timeout` - Max time to wait for a token in ms (default 35_000)
  """

  use GenServer

  alias Lux.Lenses.TelegramLens.RateLimiter

  @default_bucket_size 30
  @default_refill_rate 30
  @default_refill_interval 1_000
  @default_queue_timeout 35_000

  @type bucket :: %{tokens: float, last_refill: non_neg_integer()}
  @type opts :: keyword()

  # --------------------------------------------------------------------------
  # Client API
  # --------------------------------------------------------------------------

  @doc """
  Run a function with rate limit management.

  Acquires a token from the bucket before executing. If no tokens
  are available, blocks until one becomes available (up to queue_timeout).

  ## Parameters
  - `opts`: Keyword list with rate limiter options
  - `fun`: Zero-arity function to execute

  ## Options
  - `:skip` - Set to true to bypass rate limiting (for read operations)
  - All other options are passed to the rate limiter GenServer

  ## Returns
  Whatever `fun` returns
  """
  @spec run(opts(), (() -> result)) :: result when result: var
  def run(opts \\ [], fun) do
    if Keyword.get(opts, :skip, false) do
      fun.()
    else
      do_run(fun, opts)
    end
  end

  defp do_run(fun, opts) do
    case start_or_reuse(opts) do
      {:ok, pid} ->
        case acquire_token(pid, opts) do
          :ok ->
            try do
              fun.()
            after
              # Token is consumed on success; on error we do not refund
              # to avoid hammering a failing endpoint
              :ok
            end

          {:error, :timeout} ->
            {:error, :rate_limit_timeout}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Start a named rate limiter bucket for a bot token.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get current bucket state (for debugging/monitoring).
  """
  @spec get_state(GenServer.server()) :: bucket()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Reset the bucket (for testing).
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(pid) do
    GenServer.call(pid, :reset)
  end

  # --------------------------------------------------------------------------
  # GenServer Callbacks
  # --------------------------------------------------------------------------

  @impl true
  def init(opts) do
    bucket_size = Keyword.get(opts, :bucket_size, @default_bucket_size)
    refill_rate = Keyword.get(opts, :refill_rate, @default_refill_rate)
    refill_interval = Keyword.get(opts, :refill_interval, @default_refill_interval)
    queue_timeout = Keyword.get(opts, :queue_timeout, @default_queue_timeout)

    state = %{
      tokens: bucket_size,
      max_tokens: bucket_size,
      refill_rate: refill_rate,
      refill_interval: refill_interval,
      queue_timeout: queue_timeout,
      last_refill: current_time_ms()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    current = refill_bucket(state)
    {:reply, %{tokens: current.tokens}, current}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{tokens: @default_bucket_size, max_tokens: @default_bucket_size,
                    refill_rate: @default_refill_rate, refill_interval: @default_refill_interval,
                    queue_timeout: @default_queue_timeout, last_refill: current_time_ms()}}
  end

  @impl true
  def handle_call(:acquire, _from, state) do
    current = refill_bucket(state)

    if current.tokens >= 1.0 do
      {:reply, :ok, %{current | tokens: current.tokens - 1.0}}
    else
      {:reply, {:wait, current.tokens}, current}
    end
  end

  # --------------------------------------------------------------------------
  # Internal
  # --------------------------------------------------------------------------

  defp acquire_token(pid, opts) do
    queue_timeout = Keyword.get(opts, :queue_timeout, @default_queue_timeout)

    case GenServer.call(pid, :acquire, queue_timeout) do
      :ok -> :ok
      {:wait, _tokens} ->
        :timer.sleep(50)
        acquire_token(pid, opts)
    end
  end

  defp refill_bucket(%{tokens: tokens, max_tokens: max, refill_rate: rate,
                       refill_interval: interval, last_refill: last} = state) do
    now = current_time_ms()
    elapsed = now - last

    if elapsed >= interval do
      cycles = div(elapsed, interval)
      new_tokens = min(max, tokens + (cycles * rate))
      %{state | tokens: new_tokens, last_refill: now}
    else
      state
    end
  end

  defp current_time_ms do
    System.system_time(:millisecond)
  end

  defp start_or_reuse(opts) do
    # Each token = bot token hash for isolation, global bucket
    token = Keyword.get(opts, :token, "default")
    name = via_tuple(token)
    Process.sleep(0)  # allow other processes

    case GenServer.start_link(__MODULE__, opts, name: name) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  rescue
    _ -> {:error, :rate_limiter_unavailable}
  end

  defp via_tuple(token) do
    key = :erlang.phash2(token)
    {:via, Registry, {Lux.Lenses.TelegramLens.RateLimiter.Registry, key}}
  end
end
