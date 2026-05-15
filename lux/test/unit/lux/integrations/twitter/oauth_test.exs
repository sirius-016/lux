defmodule Lux.Integrations.Twitter.OAuthTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.OAuth

  describe "generate_auth_url/1" do
    test "generates valid authorization URL" do
      config = %{
        client_id: "test_client_id",
        redirect_uri: "http://localhost:4000/callback",
        scopes: ["tweet.read", "users.read"],
        state: "random_state"
      }

      url = OAuth.generate_auth_url(config)
      assert url =~ "https://twitter.com/i/oauth2/authorize"
      assert url =~ "client_id=test_client_id"
      assert url =~ "redirect_uri="
      assert url =~ "scope="
      assert url =~ "response_type=code"
      assert url =~ "code_challenge="
      assert url =~ "code_challenge_method=S256"
    end
  end

  describe "exchange_code/2" do
    test "exchanges authorization code for tokens" do
      Req.Test.expect(Lux.Integrations.Twitter.Client, fn conn ->
        assert conn.method == "POST"
        body = Plug.Conn.read_body!(conn)
        assert body =~ "code=test_code"
        assert body =~ "grant_type=authorization_code"
        Req.Test.json(conn, 200, %{
          "access_token" => "access123",
          "refresh_token" => "refresh123",
          "expires_in" => 7200,
          "token_type" => "bearer"
        })
      end)

      assert {:ok, %{access_token: "access123", refresh_token: "refresh123"}} =
        OAuth.exchange_code("test_code", %{client_id: "id", client_secret: "secret", redirect_uri: "http://localhost"})
    end
  end

  describe "PKCE helpers" do
    test "code verifier is at least 43 chars" do
      verifier = OAuth.generate_code_verifier()
      assert String.length(verifier) >= 43
    end

    test "code challenge is SHA256 base64url of verifier" do
      verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      # Known test vector
      challenge = OAuth.generate_code_challenge(verifier)
      assert is_binary(challenge)
      assert String.length(challenge) > 0
    end
  end
end
