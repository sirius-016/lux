defmodule Lux.LLM.RouterTest do
  use ExUnit.Case

  setup do
    Lux.LLM.Router.init_tables()
    :ok
  end

  describe "classify_request/2" do
    test "detects tools capability from text" do
      req = Lux.LLM.Router.classify_request("Use the search function", [])
      assert :tools in req.capabilities
    end

    test "detects vision capability from text" do
      req = Lux.LLM.Router.classify_request("Describe this image", [])
      assert :vision in req.capabilities
    end

    test "detects streaming capability from text" do
      req = Lux.LLM.Router.classify_request("Stream the response in realtime", [])
      assert :streaming in req.capabilities
    end

    test "respects explicit capabilities option" do
      req = Lux.LLM.Router.classify_request("hello", capabilities: [:tools, :vision])
      assert :tools in req.capabilities
      assert :vision in req.capabilities
    end
  end

  describe "circuit_open?/1" do
    test "returns false for unknown provider" do
      refute Lux.LLM.Router.circuit_open?(SomeProvider)
    end
  end
end
