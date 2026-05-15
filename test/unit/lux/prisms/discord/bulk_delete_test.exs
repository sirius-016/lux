defmodule Lux.Prisms.Discord.BulkDeleteMessagesTest do
  use ExUnit.Case, async: true

  describe "handler/2" do
    test "rejects single message ID" do
      assert {:error, msg} = Lux.Prisms.Discord.BulkDeleteMessages.handler(
        %{"channel_id" => "ch", "message_ids" => ["1"]}, %{})
      assert "at least 2" in msg
    end

    test "limits to 100 message IDs" do
      ids = Enum.map(1..150, &Integer.to_string/1)
      assert length(Enum.take(ids, 100)) == 100
    end
  end
end
