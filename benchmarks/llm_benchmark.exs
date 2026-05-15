# LLM Abstraction Layer Benchmarks
#
# Run with: mix run benchmarks/llm_benchmark.exs

Benchee.run(%{
  "registry lookup" => fn ->
    Lux.LLM.Registry.list_providers()
  end,
  "router classify (simple)" => fn ->
    Lux.LLM.Router.classify_request("Hello world", [])
  end,
  "router classify (tools)" => fn ->
    Lux.LLM.Router.classify_request("Use the search function to find results", [])
  end,
  "cache hash key" => fn ->
    :erlang.phash2({"prompt text", Lux.LLM.OpenAI, "gpt-4", 0.7})
  end,
  "monitoring estimate tokens" => fn ->
    Lux.LLM.Monitoring.estimate_tokens(String.duplicate("Hello world ", 100))
  end
}, memory_time: 2, time: 5)
