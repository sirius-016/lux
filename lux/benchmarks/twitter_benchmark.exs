defmodule Lux.Benchmarks.Twitter do
  @moduledoc """
  Performance benchmarks for Twitter API integration.

  Run with: mix run benchmarks/twitter_benchmark.exs
  """

  alias Lux.Integrations.Twitter.Client

  def run do
    Benchee.run(%{
      "client_request_mock" => fn ->
        # Benchmark the client request construction overhead
        build_request_opts(:get, "/tweets/123", "test_token")
      end,
      "rate_limiter_check" => fn ->
        Lux.Integrations.Twitter.RateLimiter.wait("get:/tweets")
      end,
      "response_parsing" => fn ->
        parse_tweet_response()
      end
    },
    time: 10,
    memory_time: 2
    )
  end

  defp build_request_opts(method, path, token) do
    [
      method: method,
      url: "https://api.twitter.com/2" <> path,
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Req.new()
  end

  defp parse_tweet_response do
    %{
      "data" => %{
        "id" => "1234567890",
        "text" => String.duplicate("Hello world ", 50),
        "author_id" => "9876543210",
        "created_at" => "2024-01-15T12:00:00.000Z",
        "public_metrics" => %{
          "like_count" => 1000,
          "retweet_count" => 500,
          "reply_count" => 200,
          "quote_count" => 50
        },
        "entities" => %{
          "hashtags" => [%{"tag" => "Elixir"}],
          "mentions" => [%{"username" => "elixirlang"}]
        },
        "context_annotations" => []
      },
      "includes" => %{
        "users" => [%{
          "id" => "9876543210",
          "name" => "Test User",
          "username" => "testuser"
        }]
      }
    }
  end
end

Lux.Benchmarks.Twitter.run()
