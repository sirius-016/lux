defmodule Lux.LLM.FallbackTest do
  use ExUnit.Case

  describe "circuit_open?/1" do
    test "returns false when no circuit breaker state exists" do
      refute Lux.LLM.Fallback.circuit_open?(NonExistentProvider)
    end
  end

  describe "health_score/1" do
    test "returns 1.0 for unknown provider" do
      assert Lux.LLM.Fallback.health_score(UnknownProvider) == 1.0
    end
  end
end
