defmodule Lux.Integrations.Twitter.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Client

  import Mox

  setup :verify_on_exit!

  describe "request/3" do
    test "successful GET request returns body" do
      response = %{"data" => %{"id" => "123", "text" => "Hello"}}

      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "/tweets/123"
        assert {"Authorization", "Bearer test_token"} in conn.req_headers
        Req.Test.json(conn, 200, response)
      end)

      assert {:ok, ^response} = Client.request(:get, "/tweets/123", %{token: "test_token"})
    end

    test "successful POST request returns created data" do
      response = %{"data" => %{"id" => "456", "text" => "New tweet"}}

      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/tweets"
        Req.Test.json(conn, 201, response)
      end)

      assert {:ok, ^response} = Client.request(:post, "/tweets", %{
        token: "test_token",
        json: %{text: "New tweet"}
      })
    end

    test "DELETE request returns success" do
      response = %{"data" => %{"deleted" => true}}

      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/tweets/456"
        Req.Test.json(conn, 200, response)
      end)

      assert {:ok, ^response} = Client.request(:delete, "/tweets/456", %{token: "test_token"})
    end

    test "401 unauthorized returns error" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        Req.Test.json(conn, 401, %{"errors" => [%{"message" => "Unauthorized"}]})
      end)

      assert {:error, {401, _}} = Client.request(:get, "/users/me", %{token: "bad_token"})
    end

    test "rate limit error returns rate_limited tuple" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "0")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", to_string(System.system_time(:second) + 900))
        |> Req.Test.json(429, %{"errors" => [%{"message" => "Rate limit exceeded"}]})
      end)

      assert {:error, {:rate_limited, _}} = Client.request(:get, "/tweets", %{token: "test_token"})
    end

    test "request with query params builds correct URL" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.query_string =~ "max_results=50"
        assert conn.query_string =~ "query=test"
        Req.Test.json(conn, 200, %{"data" => []})
      end)

      assert {:ok, _} = Client.request(:get, "/tweets/search/recent", %{
        token: "test_token",
        params: %{max_results: 50, query: "test"}
      })
    end
  end
end
