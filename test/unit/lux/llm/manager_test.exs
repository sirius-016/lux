defmodule Lux.LLM.ManagerTest do
  use ExUnit.Case

  describe "configure/1" do
    test "accepts configuration options without error" do
      assert :ok == Lux.LLM.Manager.configure(default_provider: Lux.LLM.OpenAI)
    end
  end

  describe "total_cost/0" do
    test "returns a numeric cost" do
      cost = Lux.LLM.Manager.total_cost()
      assert is_number(cost)
    end
  end

  describe "usage_report/0" do
    test "returns a list" do
      report = Lux.LLM.Manager.usage_report()
      assert is_list(report)
    end
  end

  describe "cache_stats/0" do
    test "returns a map with expected keys" do
      stats = Lux.LLM.Manager.cache_stats()
      assert Map.has_key?(stats, :size)
      assert Map.has_key?(stats, :hits)
      assert Map.has_key?(stats, :misses)
    end
  end
end
