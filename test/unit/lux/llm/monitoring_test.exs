defmodule Lux.LLM.MonitoringTest do
  use ExUnit.Case

  setup do
    Lux.LLM.Monitoring.start_link([])
    Lux.LLM.Monitoring.reset()
    :ok
  end

  describe "track_request/1" do
    test "records a request and increments counters" do
      Lux.LLM.Monitoring.track_request(%{
        provider: Lux.LLM.OpenAI,
        model: "gpt-4",
        latency_ms: 500,
        input_tokens: 100,
        output_tokens: 50
      })
      assert Lux.LLM.Monitoring.request_count() == 1
      stats = Lux.LLM.Monitoring.provider_stats(Lux.LLM.OpenAI)
      assert stats.request_count == 1
      assert stats.avg_latency_ms == 500.0
    end
  end

  describe "total_cost/0" do
    test "returns estimated cost" do
      Lux.LLM.Monitoring.track_request(%{
        provider: Lux.LLM.OpenAI, model: "gpt-4",
        latency_ms: 100, input_tokens: 1000, output_tokens: 500
      })
      cost = Lux.LLM.Monitoring.total_cost()
      assert cost > 0.0
    end
  end

  describe "usage_report/0" do
    test "returns a list of provider stats" do
      Lux.LLM.Monitoring.track_request(%{
        provider: Lux.LLM.OpenAI, model: "gpt-4",
        latency_ms: 200, input_tokens: 50, output_tokens: 25
      })
      report = Lux.LLM.Monitoring.usage_report()
      assert is_list(report)
      assert length(report) >= 1
    end
  end

  describe "estimate_tokens/1" do
    test "estimates token count from text" do
      assert Lux.LLM.Monitoring.estimate_tokens("Hello world") > 0
    end
  end
end
