defmodule Lux.LLM.Monitoring do
  @moduledoc """
  ETS-backed cost and performance tracking for LLM requests.

  All writes go through :ets.update_counter or direct insert for speed.
  Metrics are aggregated per provider and per model.
  """

  @stats_table :lux_llm_stats
  @requests_table :lux_llm_requests

  @doc "Start monitoring (creates ETS tables)."
  @spec start_link(keyword()) :: :ok
  def start_link(_opts \\ []) do
    if :ets.whereis(@stats_table) == :undefined do
      :ets.new(@stats_table, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    end
    if :ets.whereis(@requests_table) == :undefined do
      :ets.new(@requests_table, [:bag, :public, :named_table, read_concurrency: true])
    end
    :ok
  end

  @doc "Record a completed request."
  @spec track_request(map()) :: :ok
  def track_request(%{provider: provider, model: model, latency_ms: latency_ms, input_tokens: input_tokens, output_tokens: output_tokens} = _req) do
    now = System.system_time(:second)

    # Provider stats
    pk = {:provider, provider}
    case :ets.lookup(@stats_table, pk) do
      [^pk, s] ->
        new_count = s.request_count + 1
        new_total_latency = s.total_latency_ms + latency_ms
        new_input_tokens = s.total_input_tokens + input_tokens
        new_output_tokens = s.total_output_tokens + output_tokens
        new_total_cost = s.total_cost + estimate_cost(provider, model, input_tokens, output_tokens)
        :ets.insert(@stats_table, {pk, %{s |
          request_count: new_count,
          total_latency_ms: new_total_latency,
          total_input_tokens: new_input_tokens,
          total_output_tokens: new_output_tokens,
          total_cost: new_total_cost,
          last_request_at: now
        }})
      [] ->
        cost = estimate_cost(provider, model, input_tokens, output_tokens)
        :ets.insert(@stats_table, {pk, %{
          request_count: 1,
          total_latency_ms: latency_ms,
          total_input_tokens: input_tokens,
          total_output_tokens: output_tokens,
          total_cost: cost,
          last_request_at: now
        }})
    end

    # Model stats
    mk = {:model, provider, model}
    case :ets.lookup(@stats_table, mk) do
      [^mk, ms] ->
        :ets.insert(@stats_table, {mk, %{ms |
          request_count: ms.request_count + 1,
          total_latency_ms: ms.total_latency_ms + latency_ms,
          total_input_tokens: ms.total_input_tokens + input_tokens,
          total_output_tokens: ms.total_output_tokens + output_tokens
        }})
      [] ->
        :ets.insert(@stats_table, {mk, %{
          request_count: 1,
          total_latency_ms: latency_ms,
          total_input_tokens: input_tokens,
          total_output_tokens: output_tokens
        }})
    end

    :ok
  end

  @doc "Get aggregated stats for a provider."
  @spec provider_stats(module()) :: map()
  def provider_stats(provider) do
    case :ets.lookup(@stats_table, {:provider, provider}) do
      [_, s] ->
        %{s | avg_latency_ms: if(s.request_count > 0, do: s.total_latency_ms / s.request_count, else: 0.0)}
      [] -> %{request_count: 0, total_latency_ms: 0, avg_latency_ms: 0.0, total_cost: 0.0, total_input_tokens: 0, total_output_tokens: 0}
    end
  end

  @doc "Get aggregated stats for a specific model."
  @spec model_stats(module(), String.t()) :: map()
  def model_stats(provider, model) do
    case :ets.lookup(@stats_table, {:model, provider, model}) do
      [_, ms] -> ms
      [] -> %{request_count: 0, total_latency_ms: 0, total_input_tokens: 0, total_output_tokens: 0}
    end
  end

  @doc "Total request count across all providers."
  @spec request_count() :: non_neg_integer()
  def request_count do
    @stats_table
    |> :ets.match_object({{:provider, :_}, :_})
    |> Enum.map(fn {_, s} -> s.request_count end)
    |> Enum.sum()
  end

  @doc "Total estimated cost across all providers."
  @spec total_cost() :: float()
  def total_cost do
    @stats_table
    |> :ets.match_object({{:provider, :_}, :_})
    |> Enum.map(fn {_, s} -> s.total_cost end)
    |> Enum.sum()
  end

  @doc "Generate a usage report for all providers."
  @spec usage_report() :: [map()]
  def usage_report do
    @stats_table
    |> :ets.match_object({{:provider, :_}, :_})
    |> Enum.map(fn {{:provider, provider}, s} ->
      avg_lat = if s.request_count > 0, do: Float.round(s.total_latency_ms / s.request_count, 1), else: 0.0
      %{
        provider: provider,
        request_count: s.request_count,
        total_cost: Float.round(s.total_cost, 4),
        avg_latency_ms: avg_lat,
        total_input_tokens: s.total_input_tokens,
        total_output_tokens: s.total_output_tokens
      }
    end)
    |> Enum.sort_by(& &1.request_count, :desc)
  end

  @doc "Reset all stats."
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@stats_table)
    :ets.delete_all_objects(@requests_table)
    :ok
  end

  # ── Cost estimation ──

  @model_prices %{
    {"Lux.LLM.OpenAI", "gpt-4"} => {0.03, 0.06},
    {"Lux.LLM.OpenAI", "gpt-4-turbo"} => {0.01, 0.03},
    {"Lux.LLM.OpenAI", "gpt-3.5-turbo"} => {0.0005, 0.0015},
    {"Lux.LLM.Anthropic", "claude-3-opus-20240229"} => {0.015, 0.075},
    {"Lux.LLM.Anthropic", "claude-3-sonnet-20240229"} => {0.003, 0.015},
    {"Lux.LLM.TogetherAI", "mistral-7b-instruct"} => {0.0002, 0.0002},
    {"Lux.LLM.Mira", "llama-3.1-8b-instruct"} => {0.0002, 0.0002}
  }

  @spec estimate_cost(module(), String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(provider, model, input_tokens, output_tokens) do
    case Map.get(@model_prices, {inspect(provider), model}) do
      {in_price, out_price} ->
        (input_tokens * in_price + output_tokens * out_price) / 1_000_000
      nil ->
        # Fallback: rough estimate based on provider tier
        default_in = 0.001
        default_out = 0.003
        (input_tokens * default_in + output_tokens * default_out) / 1_000_000
    end
  end

  @doc "Approximate token count for text."
  @spec estimate_tokens(String.t()) :: non_neg_integer()
  def estimate_tokens(text) do
    # Rough estimate: ~4 characters per token
    (String.length(text) / 4) |> round()
  end
end
