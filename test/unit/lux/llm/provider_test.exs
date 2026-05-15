defmodule Lux.LLM.ProviderTest do
  use ExUnit.Case, async: true

  describe "model!/4" do
    test "creates a model info map" do
      m = Lux.LLM.Provider.model!("gpt-4", 128_000, 0.03, 0.06)
      assert m.id == "gpt-4"
      assert m.context_window == 128_000
      assert m.input_cost == 0.03
      assert m.output_cost == 0.06
    end
  end

  describe "known_providers/0" do
    test "returns the four built-in providers" do
      providers = Lux.LLM.Provider.known_providers()
      assert length(providers) == 4
      assert Lux.LLM.OpenAI in providers
      assert Lux.LLM.Anthropic in providers
      assert Lux.LLM.TogetherAI in providers
      assert Lux.LLM.Mira in providers
    end
  end
end
