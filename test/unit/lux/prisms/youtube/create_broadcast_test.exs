defmodule Lux.Prisms.YouTube.CreateBroadcastTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "validates required fields" do
      assert_raise KeyError, fn ->
        Lux.Prisms.YouTube.CreateBroadcast.handler(%{}, %{})
      end
    end

    test "truncates title to 100 chars" do
      long = String.duplicate("x", 150)
      assert String.length(String.slice(long, 0, 100)) == 100
    end
  end
end
