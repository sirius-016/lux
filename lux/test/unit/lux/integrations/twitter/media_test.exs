defmodule Lux.Integrations.Twitter.MediaTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Media

  describe "chunk_binary/2" do
    test "splits binary into correct number of chunks" do
      binary = :crypto.strong_rand_bytes(15 * 1024 * 1024)  # 15MB
      chunks = Media.chunk_binary(binary, 5 * 1024 * 1024)
      assert length(chunks) == 3
    end

    test "handles binary smaller than chunk size" do
      binary = "small content"
      chunks = Media.chunk_binary(binary, 1024)
      assert length(chunks) == 1
      assert hd(chunks) == "small content"
    end

    test "handles exact chunk size" do
      binary = :crypto.strong_rand_bytes(5 * 1024 * 1024)
      chunks = Media.chunk_binary(binary, 5 * 1024 * 1024)
      assert length(chunks) == 1
    end

    test "handles empty binary" do
      assert Media.chunk_binary(<<>>, 1024) == []
    end
  end
end
