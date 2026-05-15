defmodule Lux.LLM.CacheTest do
  use ExUnit.Case

  setup do
    Lux.LLM.Cache.start_link([])
    Lux.LLM.Cache.invalidate_all()
    Lux.LLM.Cache.reset_stats()
    :ok
  end

  describe "fetch_or_compute/5" do
    test "computes and caches on miss" do
      {:ok, resp, type} = Lux.LLM.Cache.fetch_or_compute(
        "hello", Lux.LLM.OpenAI, "gpt-4", 0.7,
        fn -> {:ok, %Lux.LLM.Response{content: "hi"}} end
      )
      assert type == :computed
      assert resp.content == "hi"
    end

    test "returns cached on hit" do
      compute_fn = fn -> {:ok, %Lux.LLM.Response{content: "cached"}} end
      Lux.LLM.Cache.fetch_or_compute("prompt", Lux.LLM.OpenAI, "gpt-4", 0.7, compute_fn)
      {:ok, resp, type} = Lux.LLM.Cache.fetch_or_compute("prompt", Lux.LLM.OpenAI, "gpt-4", 0.7, compute_fn)
      assert type == :cached
      assert resp.content == "cached"
    end
  end

  describe "stats/0" do
    test "tracks hits and misses" do
      compute_fn = fn -> {:ok, %Lux.LLM.Response{content: "x"}} end
      Lux.LLM.Cache.fetch_or_compute("a", Lux.LLM.OpenAI, "gpt-4", 0.7, compute_fn)
      Lux.LLM.Cache.fetch_or_compute("a", Lux.LLM.OpenAI, "gpt-4", 0.7, compute_fn)
      stats = Lux.LLM.Cache.stats()
      assert stats.hits >= 1
      assert stats.misses >= 1
    end
  end
end
