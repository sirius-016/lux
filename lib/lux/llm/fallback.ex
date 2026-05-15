defmodule Lux.LLM.Fallback do
  @moduledoc """
  Fallback and retry logic with per-provider circuit breakers.

  Circuit breaker states:
    - `:closed`   – normal operation
    - `:open`     – provider is failing, skip for cooldown period
    - `:half_open` – cooldown elapsed, try one request as probe
  """

  use GenServer

  alias Lux.LLM.Router

  @default_max_failures 3
  @default_cooldown_ms  30_000
  @default_max_retries  2
  @default_base_delay   500

  defstruct [:max_failures, :cooldown_ms, :max_retries, :base_delay]

  # ── Client API ──

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc """
  Execute a request against providers in order, with circuit-breaker
  checks and exponential-backoff retry.
  """
  @spec execute([module()], String.t() | [map()], [map()], keyword()) ::
          {:ok, module(), Lux.LLM.Response.t()} | {:error, String.t()}
  def execute(providers, prompt, tools, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)

    do_execute(providers, prompt, tools, max_retries, base_delay, 0, nil)
  end

  @doc "Check if a provider circuit breaker is open."
  @spec circuit_open?(module()) :: boolean()
  def circuit_open?(provider) do
    GenServer.call(__MODULE__, {:circuit_state, provider}) == :open
  end

  @doc "Get the state of a provider circuit breaker."
  @spec circuit_state(module()) :: :closed | :open | :half_open
  def circuit_state(provider) do
    GenServer.call(__MODULE__, {:circuit_state, provider})
  end

  @doc "Reset a provider circuit breaker to closed."
  @spec reset_circuit(module()) :: :ok
  def reset_circuit(provider) do
    GenServer.cast(__MODULE__, {:reset, provider})
  end

  @doc "Get health score for a provider (0.0–1.0)."
  @spec health_score(module()) :: float()
  def health_score(provider) do
    GenServer.call(__MODULE__, {:health_score, provider})
  end

  # ── GenServer callbacks ──

  @impl true
  def init(opts) do
    Router.init_tables()
    state = %__MODULE__{
      max_failures: Keyword.get(opts, :max_failures, @default_max_failures),
      cooldown_ms: Keyword.get(opts, :cooldown_ms, @default_cooldown_ms),
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      base_delay: Keyword.get(opts, :base_delay, @default_base_delay)
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:circuit_state, provider}, _from, state) do
    cs = get_circuit(provider)
    cs = maybe_transition(cs, provider)
    {:reply, cs.state, state}
  end

  @impl true
  def handle_call({:health_score, provider}, _from, state) do
    score = case get_circuit(provider) do
      %{state: :closed, failure_count: 0} -> 1.0
      %{state: :closed, failure_count: c} -> max(0.0, 1.0 - c / max(state.max_failures, 1))
      %{state: :half_open} -> 0.5
      %{state: :open} -> 0.0
    end
    {:reply, score, state}
  end

  @impl true
  def handle_cast({:reset, provider}, state) do
    set_circuit(provider, %{state: :closed, failure_count: 0, opened_at: nil})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:failure, provider}, state) do
    cs = get_circuit(provider)
    new_cs = case cs do
      %{state: :closed, failure_count: c} when c >= state.max_failures - 1 ->
        %{state: :open, failure_count: c + 1, opened_at: System.monotonic_time(:millisecond)}
      %{state: :closed, failure_count: c} ->
        %{cs | failure_count: c + 1}
      %{state: :half_open} ->
        %{state: :open, failure_count: cs.failure_count + 1, opened_at: System.monotonic_time(:millisecond)}
      other -> other
    end
    set_circuit(provider, new_cs)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:success, provider}, state) do
    set_circuit(provider, %{state: :closed, failure_count: 0, opened_at: nil})
    {:noreply, state}
  end

  # ── Internal ──

  defp do_execute([], _prompt, _tools, _retries, _delay, _err), do: {:error, "all providers failed"}

  defp do_execute([provider | rest], prompt, tools, retries, delay, _last_err) do
    cs = get_circuit(provider)
    cs = maybe_transition(cs, provider)

    case cs.state do
      :open ->
        do_execute(rest, prompt, tools, retries, delay, "circuit open for #{inspect(provider)}")
      _ ->
        case call_with_retry(provider, prompt, tools, retries, delay) do
          {:ok, resp} ->
            GenServer.cast(__MODULE__, {:success, provider})
            {:ok, provider, resp}
          {:error, reason} ->
            GenServer.cast(__MODULE__, {:failure, provider})
            do_execute(rest, prompt, tools, retries, delay, reason)
        end
    end
  end

  defp call_with_retry(provider, prompt, tools, retries_left, base_delay) do
    do_retry(provider, prompt, tools, retries_left, base_delay, nil)
  end

  defp do_retry(_provider, _prompt, _tools, 0, _delay, last_err) when last_err != nil, do: {:error, last_err}

  defp do_retry(provider, prompt, tools, retries, delay, _last_err) do
    case provider.call(prompt, tools, []) do
      {:ok, _} = ok -> ok
      {:error, _} = err ->
        if retries > 0 do
          jitter = :rand.uniform(delay)
          Process.sleep(delay + jitter)
          do_retry(provider, prompt, tools, retries - 1, delay * 2, nil)
        else
          err
        end
    end
  end

  defp get_circuit(provider) do
    case :ets.lookup(:lux_llm_circuits, provider) do
      [{^provider, cs}] -> cs
      [] -> %{state: :closed, failure_count: 0, opened_at: nil}
    end
  end

  defp set_circuit(provider, cs) do
    :ets.insert(:lux_llm_circuits, {provider, cs})
  end

  defp maybe_transition(%{state: :open, opened_at: opened_at} = cs, provider) do
    cooldown = 30_000
    if System.monotonic_time(:millisecond) - opened_at > cooldown do
      new_cs = %{cs | state: :half_open}
      set_circuit(provider, new_cs)
      new_cs
    else
      cs
    end
  end

  defp maybe_transition(cs, _provider), do: cs
end

defmodule Lux.LLM.Fallback.CircuitBreaker do
  @moduledoc false
  # Alias for Router compatibility
  use GenServer

  def start_link(_), do: {:ok, :ok}
  def handle_cast({:failure, p}, _), do: Lux.LLM.Fallback.record_failure(p); {:noreply, []}
  def handle_cast({:success, p}, _), do: Lux.LLM.Fallback.record_success(p); {:noreply, []}
  def handle_call(_, _, s), do: {:reply, nil, s}
end
