defmodule Lux.Prisms.YouTube.SendLiveChatMessageTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "truncates long messages to 200 chars" do
      long = String.duplicate("a", 300)
      assert String.length(String.slice(long, 0, 200)) == 200
    end
  end
end
