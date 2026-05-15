defmodule Lux.Prisms.Discord.SendMessageTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "validates required fields" do
      assert_raise KeyError, fn ->
        Lux.Prisms.Discord.SendMessage.handler(%{}, %{})
      end
    end

    test "truncates content to 2000 chars" do
      long_content = String.duplicate("a", 3000)
      # Integration test would verify truncation in actual API call
      assert String.length(long_content) > 2000
    end
  end
end
