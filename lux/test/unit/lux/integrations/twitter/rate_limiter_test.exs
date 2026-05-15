defmodule Lux.Integrations.Twitter.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Twitter.RateLimiter

  setup do
    # RateLimiter uses ETS named table, ensure it is started
    try do
      :ets.delete(:twitter_rate_limits)
    rescue
      ArgumentError -> :ok
    end
    {:ok, pid} = RateLimiter.start_link([])
    %{pid: pid}
  end

  describe "wait/1" do
    test "returns immediately when no limits set" do
      assert :ok == RateLimiter.wait("get:/tweets")
    end

    test "waits when remaining is 0 and reset is in future" do
      reset_at = System.system_time(:second) + 1
      :ets.insert(:twitter_rate_limits, {"get:/tweets", 0, reset_at})
      assert :ok == RateLimiter.wait("get:/tweets")
    end
  end

  describe "update_limits/3" do
    test "stores rate limit info" do
      RateLimiter.update_limits("get:/tweets", 100, 1700000000)
      Process.sleep(50)  # Wait for cast
      assert {100, 1700000000} == RateLimiter.get_limits("get:/tweets")
    end
  end

  describe "get_limits/1" do
    test "returns nil for unknown endpoint" do
      assert nil == RateLimiter.get_limits("unknown:/endpoint")
    end
  end

  describe "decrement/1" do
    test "decrements remaining count" do
      :ets.insert(:twitter_rate_limits, {"post:/tweets", 5, 1700000000})
      RateLimiter.decrement("post:/tweets")
      Process.sleep(50)
      assert {4, 1700000000} == RateLimiter.get_limits("post:/tweets")
    end

    test "does not go below 0" do
      :ets.insert(:twitter_rate_limits, {"post:/tweets", 0, 1700000000})
      RateLimiter.decrement("post:/tweets")
      Process.sleep(50)
      assert {0, 1700000000} == RateLimiter.get_limits("post:/tweets")
    end
  end
end
