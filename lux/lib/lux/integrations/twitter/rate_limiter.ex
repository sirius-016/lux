defmodule Lux.Integrations.Twitter.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for Twitter API.

  Tracks rate limits per endpoint using ETS and enforces wait times
  before requests can be made. Automatically updates limits from
  Twitter API response headers (x-rate-limit-remaining, x-rate-limit-reset).

  ## Usage

      RateLimiter.wait("get:/2/tweets")
      RateLimiter.update_limits("/2/tweets", 890, 1700000000)
  """

  use GenServer

  @table_name :twitter_rate_limits
  @default_limit 900
  @default_window 900

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Blocks until the endpoint is available for requests."
  @spec wait(String.t()) :: :ok
  def wait(endpoint_key) do
    case :ets.lookup(@table_name, endpoint_key) do
      [{^endpoint_key, remaining, reset_at}] ->
        now = System.system_time(:second)
        if remaining <= 0 and reset_at > now do
          Process.sleep(reset_at - now)
        end
        :ok
      [] ->
        :ok
    end
  end

  @doc "Updates rate limit info from Twitter response headers."
  @spec update_limits(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def update_limits(path, remaining, reset_at) do
    GenServer.cast(__MODULE__, {:update_limits, path, remaining, reset_at})
    :ok
  end

  @doc "Decrements the remaining count for an endpoint."
  @spec decrement(String.t()) :: :ok
  def decrement(endpoint_key) do
    GenServer.cast(__MODULE__, {:decrement, endpoint_key})
    :ok
  end

  @doc "Gets current rate limit info for an endpoint."
  @spec get_limits(String.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_limits(endpoint_key) do
    case :ets.lookup(@table_name, endpoint_key) do
      [{^endpoint_key, remaining, reset_at}] -> {remaining, reset_at}
      [] -> nil
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:update_limits, path, remaining, reset_at}, state) do
    :ets.insert(@table_name, {path, remaining, reset_at})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:decrement, endpoint_key}, state) do
    case :ets.lookup(@table_name, endpoint_key) do
      [{^endpoint_key, remaining, reset_at}] when remaining > 0 ->
        :ets.insert(@table_name, {endpoint_key, remaining - 1, reset_at})
      _ ->
        :ok
    end
    {:noreply, state}
  end
end
