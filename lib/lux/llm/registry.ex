defmodule Lux.LLM.Registry do
  @moduledoc """
  ETS-backed central registry for LLM providers and their models.

  All public reads go through ETS so they never become a GenServer bottleneck.
  """

  use GenServer

  @registry_table :lux_llm_registry
  @models_table   :lux_llm_models

  defstruct []

  # ── Client API ──

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @spec register_provider(module(), map()) :: :ok
  def register_provider(module, _metadata) when is_atom(module) do
    GenServer.cast(__MODULE__, {:register_provider, module})
  end

  @spec unregister_provider(module()) :: :ok
  def unregister_provider(module) when is_atom(module) do
    GenServer.cast(__MODULE__, {:unregister_provider, module})
  end

  @spec list_providers() :: [module()]
  def list_providers do
    case :ets.lookup(@registry_table, :providers) do
      [{:providers, list}] -> list
      [] -> []
    end
  end

  @spec get_provider(atom() | String.t()) :: module() | nil
  def get_provider(name) when is_atom(name) do
    Enum.find(list_providers(), &(&1 == name))
  end

  def get_provider(name) when is_binary(name) do
    Enum.find(list_providers(), &(Lux.LLM.Provider.name(&1) == name))
  end

  def get_provider(_), do: nil

  @spec set_default(module()) :: :ok
  def set_default(module) when is_atom(module) do
    :ets.insert(@registry_table, {:default_provider, module})
    :ok
  end

  @spec get_default() :: module() | nil
  def get_default do
    case :ets.lookup(@registry_table, :default_provider) do
      [{:default_provider, mod}] -> mod
      [] -> nil
    end
  end

  @spec register_model(module(), map()) :: :ok
  def register_model(provider, model_info) when is_atom(provider) do
    :ets.insert(@models_table, {{provider, model_info.id}, model_info})
    :ok
  end

  @spec find_model([module()], keyword()) :: {module(), map()} | nil
  def find_model(providers, opts \\ []) do
    required_caps = Keyword.get(opts, :capabilities, []) |> MapSet.new()
    min_context = Keyword.get(opts, :min_context, 0)

    providers
    |> Enum.flat_map(fn provider ->
      provider_caps = Lux.LLM.Provider.capabilities(provider) |> MapSet.new()
      if MapSet.subset?(required_caps, provider_caps) do
        Lux.LLM.Provider.models(provider)
        |> Enum.filter(&(&1.context_window >= min_context))
        |> Enum.map(&{&1.input_cost + &1.output_cost, provider, &1})
      else
        []
      end
    end)
    |> Enum.sort()
    |> List.first()
    |> case do
      nil -> nil
      {_cost, provider, model} -> {provider, model}
    end
  end

  @spec list_models(module()) :: [map()]
  def list_models(provider) when is_atom(provider) do
    :ets.match_object(@models_table, {{provider, :_}, :_})
    |> Enum.map(fn {{_, _}, model} -> model end)
  end

  @spec put(atom(), term()) :: :ok
  def put(key, value) do
    :ets.insert(@registry_table, {key, value})
    :ok
  end

  @spec get(atom()) :: term() | nil
  def get(key) do
    case :ets.lookup(@registry_table, key) do
      [{^key, val}] -> val
      [] -> nil
    end
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    :ets.new(@registry_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@models_table, [:set, :public, :named_table, read_concurrency: true])

    providers = Lux.LLM.Provider.known_providers()
    :ets.insert(@registry_table, {:providers, providers})
    :ets.insert(@registry_table, {:default_provider, Lux.LLM.OpenAI})

    for provider <- providers do
      for model <- Lux.LLM.Provider.models(provider) do
        :ets.insert(@models_table, {{provider, model.id}, model})
      end
    end

    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:register_provider, module}, state) do
    providers = [module | list_providers()] |> Enum.uniq()
    :ets.insert(@registry_table, {:providers, providers})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:unregister_provider, module}, state) do
    providers = list_providers() |> Enum.reject(&(&1 == module))
    :ets.insert(@registry_table, {:providers, providers})

    :ets.match_object(@models_table, {{module, :_}, :_})
    |> Enum.each(&:ets.delete(@models_table, &1))

    {:noreply, state}
  end
end
