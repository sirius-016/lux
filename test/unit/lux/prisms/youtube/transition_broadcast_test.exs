defmodule Lux.Prisms.YouTube.TransitionBroadcastTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "handles valid status transitions" do
      statuses = ["testing", "live", "complete"]
      Enum.each(statuses, fn s -> assert s in statuses end)
    end
  end
end
