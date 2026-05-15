defmodule Lux.LLM.Router do
  @moduledoc """
  Intelligent request routing across LLM providers.

  Strategies:
    - `:cost`        – pick the cheapest model that meets requirements
    - `:latency`     – pick the historically fastest provider
    - `:quality`     – pick the provider with the largest context window
    - `:round_robin` – cycle through providers evenly
    - `:fallback`    – try providers in order until one succeeds
  """

  alias Lux.LLM.{Provider, Registry, Monitoring, Fallback}

  @state_table   :lux_llm_router_state
  @circuit_table :lux_llm_circuits

  @default_strategy Application.compile_env(:lux, [:llm_router, :strategy], :cost)
  @fallback_chain  Application.compile_env(:lux, [:llm_router, :fallback_chain],
    [Lux.LLM.OpenAI, Lux.LLM.Anthropic, Lux.LLM.TogetherAI, Lux.LLM.Mira])

  # ── Public API ──

  @spec route(String.t() | [map()], [map()], keyword()) :: {:ok, module()} | {:error, String.t()}
  def route(prompt, tools, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, @default_strategy)
    request = classify_request(prompt, opts)
    route_by_strategy(strategy, request, opts)
  end

  @spec route_with_fallback(String.t() | [map()], [map()], keyword()) ::
          {:ok, module(), Lux.LLM.Response.t()} | {:error, String.t()}
  def route_with_fallback(prompt, tools, opts \\ []) do
    chain = Keyword.get(opts, :chain, @fallback_chain)
    request = classify_request(prompt, opts)
    candidates = filter_by_capabilities(chain, request)

    Fallback.execute(candidates, prompt, tools, opts)
  end

  @spec classify_request(String.t() | [map()], keyword()) :: map()
  def classify_request(prompt, opts) do
    text = if is_list(prompt), do: inspect(prompt), else: to_string(prompt)
    min_context = Keyword.get(opts, :min_context, 0)

    caps = Keyword.get(opts, :capabilities, [])
    caps = maybe_detect_tools(caps, text)
    caps = maybe_detect_vision(caps, text)
    caps = maybe_detect_streaming(caps, text)
    caps = Enum.uniq(caps)

    %{capabilities: caps, min_context: min_context, text: text}
  end

  @spec circuit_open?(module()) :: boolean()
  def circuit_open?(provider) do
    case :ets.lookup(@circuit_table, provider) do
      [{_, :open, _}] -> true
      _ -> false
    end
  end

  @spec record_failure(module()) :: :ok
  def record_failure(provider) do
    GenServer.cast(Lux.LLM.Fallback.CircuitBreaker, {:failure, provider})
  end

  @spec record_success(module()) :: :ok
  def record_success(provider) do
    GenServer.cast(Lux.LLM.Fallback.CircuitBreaker, {:success, provider})
  end

  def init_tables do
    if :ets.whereis(@state_table) != :undefined, do: :ets.delete(@state_table)
    if :ets.whereis(@circuit_table) != :undefined, do: :ets.delete(@circuit_table)
    :ets.new(@state_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@circuit_table, [:set, :public, :named_table, read_concurrency: true])
    :ok
  end

  # ── Strategy implementations ──

  defp route_by_strategy(:cost, req, _opts) do
    providers = Registry.list_providers() |> filter_by_capabilities(req)
    case Registry.find_model(providers, capabilities: req.capabilities, min_context: req.min_context) do
      {provider, _model} -> {:ok, provider}
      nil -> {:error, "no model satisfies requirements"}
    end
  end

  defp route_by_strategy(:latency, req, _opts) do
    providers = Registry.list_providers() |> filter_by_capabilities(req)

    candidates = for p <- providers,
        stats = Monitoring.provider_stats(p),
        stats.request_count > 0 do
      {stats.avg_latency_ms || :infinity, p}
    end

    case candidates do
      [] -> route_by_strategy(:quality, req, [])
      sorted -> {:ok, sorted |> Enum.min_by(&elem(&1, 0)) |> elem(1)}
    end
  end

  defp route_by_strategy(:quality, req, _opts) do
    providers = Registry.list_providers() |> filter_by_capabilities(req)
    case providers do
      [] -> {:error, "no provider satisfies requirements"}
      list ->
        best = Enum.max_by(list, fn p ->
          p |> Provider.models() |> Enum.map(& &1.context_window) |> Enum.max(fn -> 0 end)
        end)
        {:ok, best}
    end
  end

  defp route_by_strategy(:round_robin, req, _opts) do
    providers = Registry.list_providers() |> filter_by_capabilities(req)
    try do
      counter = :ets.update_counter(@state_table, :rr_counter, {2, 1}, {:rr_counter, 0})
      idx = rem(counter, max(1, length(providers)))
      case Enum.at(providers, idx) do
        nil -> route_by_strategy(:quality, req, [])
        p -> {:ok, p}
      end
    rescue
      ArgumentError -> {:error, "router tables not initialized"}
    end
  end

  defp route_by_strategy(:fallback, req, opts) do
    chain = Keyword.get(opts, :chain, @fallback_chain)
    providers = filter_by_capabilities(chain, req)
    case providers do
      [] -> {:error, "no provider in fallback chain satisfies requirements"}
      [first | _] -> {:ok, first}
    end
  end

  # ── Helpers ──

  defp filter_by_capabilities(providers, req) do
    required = MapSet.new(req.capabilities)
    Enum.filter(providers, fn p ->
      caps = MapSet.new(Provider.capabilities(p))
      MapSet.subset?(required, caps)
    end)
  end

  defp maybe_detect_tools(caps, text) do
    if String.contains?(text, ["function", "tool", "call", "execute", "action"]),
      do: [:tools | caps], else: caps
  end

  defp maybe_detect_vision(caps, text) do
    if String.contains?(text, ["image", "picture", "photo", "vision"]),
      do: [:vision | caps], else: caps
  end

  defp maybe_detect_streaming(caps, text) do
    if String.contains?(text, ["stream", "realtime", "live"]),
      do: [:streaming | caps], else: caps
  end
end
