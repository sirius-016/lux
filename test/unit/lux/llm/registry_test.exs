defmodule Lux.LLM.RegistryTest do
  use ExUnit.Case

  setup do
    # Ensure ETS tables exist
    if :ets.whereis(:lux_llm_registry) == :undefined do
      :ets.new(:lux_llm_registry, [:set, :public, :named_table, read_concurrency: true])
      :ets.new(:lux_llm_models, [:set, :public, :named_table, read_concurrency: true])
      :ets.insert(:lux_llm_registry, {:providers, []})
      :ets.insert(:lux_llm_registry, {:default_provider, nil})
    end
    :ok
  end

  describe "register_provider/2" do
    test "adds a provider to the registry" do
      Lux.LLM.Registry.register_provider(TestProvider, %{name: "test"})
      assert TestProvider in Lux.LLM.Registry.list_providers()
    end
  end

  describe "list_providers/0" do
    test "returns all registered providers" do
      providers = Lux.LLM.Registry.list_providers()
      assert is_list(providers)
    end
  end

  describe "set_default/1 and get_default/0" do
    test "sets and gets the default provider" do
      Lux.LLM.Registry.set_default(TestProvider)
      assert Lux.LLM.Registry.get_default() == TestProvider
    end
  end

  describe "register_model/2" do
    test "registers a model for a provider" do
      model = Lux.LLM.Provider.model!("test-model", 4096, 0.001, 0.002)
      Lux.LLM.Registry.register_model(TestProvider, model)
      models = Lux.LLM.Registry.list_models(TestProvider)
      assert length(models) >= 1
    end
  end

  describe "put/2 and get/1" do
    test "stores and retrieves custom key-value pairs" do
      Lux.LLM.Registry.put(:my_key, "my_value")
      assert Lux.LLM.Registry.get(:my_key) == "my_value"
    end
  end
end

defmodule TestProvider do
  def metadata, do: %{name: "test", models: [], capabilities: [:tools]}
  def call(_prompt, _tools, _opts), do: {:ok, %Lux.LLM.Response{content: "test"}}
  def health_check, do: :ok
end
