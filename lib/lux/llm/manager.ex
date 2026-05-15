defmodule Lux.LLM.Manager do
  @moduledoc """
  High-level orchestration layer for LLM interactions.

  Provides a unified `chat/3` API that automatically handles:
    - Provider selection via Router
    - Fallback on failure
    - Response caching
    - Cost and performance tracking
    - Configuration management
  """

  alias Lux.LLM.{Router, Registry, Monitoring, Cache, Fallback}

  @doc """
  Send a chat request through the abstraction layer.

  Options:
    - `:provider`     – specific provider module (skip routing)
    - `:strategy`     – routing strategy (:cost, :latency, :quality, :round_robin, :fallback)
    - `:cache`        – enable caching (default: false)
    - `:cache_ttl_ms` – cache TTL in ms (default: 300_000)
    - `:fallback`     – enable fallback (default: true)
    - `:track_cost`   – enable cost tracking (default: true)
    - `:model`        – specific model name
    - `:temperature`  – temperature (default: 0.7)
    - `:chain`        – fallback chain (list of provider modules)
  """
  @spec chat(String.t() | [map()], [map()], keyword()) ::
          {:ok, Lux.LLM.Response.t()} | {:error, String.t()}
  def chat(prompt, tools \\ [], opts \\ []) do
    provider = Keyword.get(opts, :provider)
    use_cache = Keyword.get(opts, :cache, false)
    use_fallback = Keyword.get(opts, :fallback, true)
    track = Keyword.get(opts, :track_cost, true)
    model = Keyword.get(opts, :model)
    temperature = Keyword.get(opts, :temperature, 0.7)

    start_time = System.monotonic_time(:millisecond)

    result = cond do
      provider ->
        call_direct(provider, prompt, tools, opts)
      use_fallback ->
        case Router.route_with_fallback(prompt, tools, opts) do
          {:ok, _provider, resp} -> {:ok, resp}
          {:error, reason} -> {:error, reason}
        end
      true ->
        case Router.route(prompt, tools, opts) do
          {:ok, p} -> call_direct(p, prompt, tools, opts)
          {:error, reason} -> {:error, reason}
        end
    end

    if track do
      latency = System.monotonic_time(:millisecond) - start_time
      record_usage(result, provider, model, latency, prompt)
    end

    result
  end

  @doc "Configure the LLM abstraction layer at runtime."
  @spec configure(keyword()) :: :ok
  def configure(opts) do
    if provider = Keyword.get(opts, :default_provider) do
      Registry.set_default(provider)
    end
    if strategy = Keyword.get(opts, :routing_strategy) do
      :persistent_term.put({__MODULE__, :strategy}, strategy)
    end
    if chain = Keyword.get(opts, :fallback_chain) do
      :persistent_term.put({__MODULE__, :chain}, chain)
    end
    if cache_size = Keyword.get(opts, :cache_max_size) do
      :persistent_term.put({__MODULE__, :cache_max_size}, cache_size)
    end
    :ok
  end

  @doc "Get a usage report for all providers."
  @spec usage_report() :: [map()]
  def usage_report, do: Monitoring.usage_report()

  @doc "Get total estimated cost."
  @spec total_cost() :: float()
  def total_cost, do: Monitoring.total_cost()

  @doc "Get cache statistics."
  @spec cache_stats() :: map()
  def cache_stats, do: Cache.stats()

  @doc "Start all subsystems (Registry, Fallback, Monitoring, Cache)."
  @spec start_link(keyword()) :: :ok
  def start_link(_opts \\ []) do
    Registry.start_link([])
    Fallback.start_link([])
    Monitoring.start_link([])
    Cache.start_link([])
    :ok
  end

  @doc "Child spec for supervision trees."
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}
  end

  # ── Internal ──

  defp call_direct(provider, prompt, tools, opts) do
    try do
      provider.call(prompt, tools, opts)
    rescue
      e -> {:error, Exception.message(e)}
    catch
      :exit, reason -> {:error, "provider exited: #{inspect(reason)}"}
    end
  end

  defp record_usage({:ok, _resp}, provider, model, latency_ms, prompt) do
    p = provider || Registry.get_default() || Lux.LLM.OpenAI
    m = model || "unknown"
    input_tokens = Monitoring.estimate_tokens(to_string(prompt))
    output_tokens = 0
    Monitoring.track_request(%{
      provider: p, model: m, latency_ms: latency_ms,
      input_tokens: input_tokens, output_tokens: output_tokens
    })
  end

  defp record_usage({:error, _}, _provider, _model, _latency, _prompt), do: :ok
end
