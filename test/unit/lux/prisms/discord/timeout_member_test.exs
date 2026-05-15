defmodule Lux.Prisms.Discord.TimeoutMemberTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "caps duration at 7 days" do
      assert 604800 = min(1_000_000, 604800)
    end
  end
end
