defmodule Lux.LLM.Cache do
  @moduledoc """
  ETS-based LRU response cache with TTL support.

  Uses a simple list-based LRU tracking and ETS for storage.
  Cache keys are derived from prompt + model + temperature.
  """

  @cache_table :lux_llm_cache
  @lru_table   :lux_llm_cache_lru

  @default_max_size 1000
  @default_ttl_ms   300_000

  defstruct max_size: @default_max_size, ttl_ms: @default_ttl_ms

  @doc "Start the cache (creates ETS tables)."
  @spec start_link(keyword()) :: :ok
  def start_link(opts \\ []) do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])
    end
    if :ets.whereis(@lru_table) == :undefined do
      :ets.new(@lru_table, [:set, :public, :named_table])
    end
    :ok
  end

  @doc """
  Fetch from cache, or compute and cache the result.
  Returns `{:ok, response, :cached}` or `{:ok, response, :computed}` or `{:error, reason}`.
  """
  @spec fetch_or_compute(String.t(), module(), String.t(), number(), (-> {:ok, Lux.LLM.Response.t()} | {:error, String.t()})) ::
          {:ok, Lux.LLM.Response.t(), :cached | :computed} | {:error, String.t()}
  def fetch_or_compute(prompt, provider, model, temperature, compute_fn) do
    key = cache_key(prompt, provider, model, temperature)

    case :ets.lookup(@cache_table, key) do
      [{^key, response, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          touch_lru(key)
          {:ok, response, :cached}
        else
          :ets.delete(@cache_table, key)
          delete_lru(key)
          compute_and_cache(key, compute_fn)
        end
      [] ->
        compute_and_cache(key, compute_fn)
    end
  end

  @doc "Look up a cached response."
  @spec get(String.t(), module(), String.t(), number()) :: {:ok, Lux.LLM.Response.t()} | :miss
  def get(prompt, provider, model, temperature) do
    key = cache_key(prompt, provider, model, temperature)
    case :ets.lookup(@cache_table, key) do
      [{^key, response, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          touch_lru(key)
          {:ok, response}
        else
          :ets.delete(@cache_table, key)
          :miss
        end
      [] -> :miss
    end
  end

  @doc "Manually insert into cache."
  @spec put(String.t(), module(), String.t(), number(), Lux.LLM.Response.t(), keyword()) :: :ok
  def put(prompt, provider, model, temperature, response, opts \\ []) do
    ttl = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    key = cache_key(prompt, provider, model, temperature)
    evict_if_full()
    :ets.insert(@cache_table, {key, response, System.monotonic_time(:millisecond) + ttl})
    touch_lru(key)
    :ok
  end

  @doc "Invalidate all cache entries."
  @spec invalidate_all() :: :ok
  def invalidate_all do
    :ets.delete_all_objects(@cache_table)
    :ets.delete_all_objects(@lru_table)
    :ok
  end

  @doc "Cache statistics."
  @spec stats() :: %{size: non_neg_integer(), hits: non_neg_integer(), misses: non_neg_integer()}
  def stats do
    size = :ets.info(@cache_table, :size)
    hits = case :ets.lookup(@lru_table, :hits) do [{_, h}] -> h; [] -> 0 end
    misses = case :ets.lookup(@lru_table, :misses) do [{_, m}] -> m; [] -> 0 end
    %{size: size, hits: hits, misses: misses, hit_rate: if(hits + misses > 0, do: hits / (hits + misses), else: 0.0)}
  end

  @spec reset_stats() :: :ok
  def reset_stats do
    :ets.insert(@lru_table, {:hits, 0})
    :ets.insert(@lru_table, {:misses, 0})
    :ok
  end

  # ── Internal ──

  defp cache_key(prompt, provider, model, temperature) do
    :erlang.phash2({prompt, provider, model, temperature})
  end

  defp compute_and_cache(key, compute_fn) do
    record_miss()
    case compute_fn.() do
      {:ok, response} ->
        evict_if_full()
        :ets.insert(@cache_table, {key, response, System.monotonic_time(:millisecond) + @default_ttl_ms})
        touch_lru(key)
        {:ok, response, :computed}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp touch_lru(key) do
    record_hit()
    # Simple LRU: delete old entry and re-insert (moves to "end")
    :ets.delete(@lru_table, {:lru, key})
    :ets.insert(@lru_table, {:lru, key})
  end

  defp delete_lru(key) do
    :ets.delete(@lru_table, {:lru, key})
  end

  defp evict_if_full do
    size = :ets.info(@cache_table, :size)
    if size >= @default_max_size do
      # Evict oldest entries (first inserted LRU keys)
      case :ets.first(@lru_table) do
        :"$end_of_table" -> :ok
        {:lru, old_key} ->
          :ets.delete(@lru_table, {:lru, old_key})
          :ets.delete(@cache_table, old_key)
          :ok
        _ -> :ok
      end
    end
  end

  defp record_hit do
    try do
      :ets.update_counter(@lru_table, :hits, {2, 1}, {:hits, 0})
    rescue
      ArgumentError -> :ok
    end
  end

  defp record_miss do
    try do
      :ets.update_counter(@lru_table, :misses, {2, 1}, {:misses, 0})
    rescue
      ArgumentError -> :ok
    end
  end
end
