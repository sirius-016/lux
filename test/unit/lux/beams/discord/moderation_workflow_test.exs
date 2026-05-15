defmodule Lux.Beams.Discord.ModerationWorkflowTest do
  use ExUnit.Case, async: true

  describe "escalate?/1" do
    test "returns ban for high severity" do
      assert "ban" == Lux.Beams.Discord.ModerationWorkflow.escalate?(%{severity: "high"})
    end

    test "returns timeout for medium severity" do
      assert "timeout" == Lux.Beams.Discord.ModerationWorkflow.escalate?(%{severity: "medium"})
    end

    test "returns nil for low severity" do
      assert nil == Lux.Beams.Discord.ModerationWorkflow.escalate?(%{severity: "low"})
    end
  end
end
