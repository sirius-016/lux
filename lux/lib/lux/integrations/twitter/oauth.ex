defmodule Lux.Integrations.Twitter.OAuth do
  @moduledoc """
  OAuth 2.0 PKCE flow implementation for Twitter API v2.

  Supports the Authorization Code Flow with PKCE (Proof Key for Code Exchange)
  for user-context authentication, as well as client_credentials grant for
  app-only authentication.

  ## Configuration

  Add to your config:

      config :lux, :twitter,
        client_id: "YOUR_CLIENT_ID",
        client_secret: "YOUR_CLIENT_SECRET",
        redirect_uri: "http://localhost:4000/callback"

  ## Usage

      # Generate authorization URL
      {:ok, url, verifier} = Lux.Integrations.Twitter.OAuth.authorization_url()

      # After user authorizes, exchange code for token
      {:ok, token} = Lux.Integrations.Twitter.OAuth.exchange_code(code, verifier)

      # Refresh expired token
      {:ok, new_token} = Lux.Integrations.Twitter.OAuth.refresh_token(refresh_token)
  """

  @authorize_url "https://twitter.com/i/oauth2/authorize"
  @token_url "https://api.twitter.com/2/oauth2/token"
  @default_scopes ~w(tweet.read tweet.write users.read follows.read follows.write like.read like.write bookmark.read bookmark.write)

  @doc """
  Generates the authorization URL and PKCE verifier for the OAuth 2.0 flow.

  ## Parameters

    - `opts` - Options map:
      - `:scope` - List of OAuth scopes (default: all read/write scopes)
      - `:state` - State parameter for CSRF protection (auto-generated if nil)
      - `:redirect_uri` - Override redirect URI

  ## Returns

    - `{:ok, url, verifier}` - Authorization URL and code verifier
  """
  @spec authorization_url(map()) :: {:ok, String.t(), String.t()}
  def authorization_url(opts \\ %{}) do
    verifier = generate_code_verifier()
    challenge = generate_code_challenge(verifier)
    state = opts[:state] || generate_state()
    scope = opts[:scope] || @default_scopes
    redirect_uri = opts[:redirect_uri] || get_redirect_uri()

    params = %{
      response_type: "code",
      client_id: get_client_id(),
      redirect_uri: redirect_uri,
      scope: Enum.join(scope, " "),
      state: state,
      code_challenge: challenge,
      code_challenge_method: "S256"
    }

    url = @authorize_url <> "?" <> URI.encode_query(params)
    {:ok, url, verifier}
  end

  @doc """
  Exchanges an authorization code for an access token.

  ## Parameters

    - `code` - Authorization code received from callback
    - `verifier` - PKCE code verifier from `authorization_url/1`
    - `opts` - Options map:
      - `:redirect_uri` - Override redirect URI

  ## Returns

    - `{:ok, token_response}` - Token response with access_token, refresh_token, etc.
    - `{:error, term()}` - Error from token exchange
  """
  @spec exchange_code(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def exchange_code(code, verifier, opts \\ %{}) do
    redirect_uri = opts[:redirect_uri] || get_redirect_uri()

    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      code_verifier: verifier,
      client_id: get_client_id()
    }

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{base64_credentials()}"}
    ]

    send_token_request(body, headers)
  end

  @doc """
  Refreshes an expired access token using a refresh token.

  ## Parameters

    - `refresh_token` - The refresh token from a previous token exchange

  ## Returns

    - `{:ok, token_response}` - New token response
    - `{:error, term()}` - Error from token refresh
  """
  @spec refresh_token(String.t()) :: {:ok, map()} | {:error, term()}
  def refresh_token(refresh_token) do
    body = %{
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: get_client_id()
    }

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{base64_credentials()}"}
    ]

    send_token_request(body, headers)
  end

  @doc """
  Obtains an app-only bearer token using client_credentials grant.

  ## Returns

    - `{:ok, %{"access_token" => token}}` - Bearer token
    - `{:error, term()}` - Error from token request
  """
  @spec client_credentials() :: {:ok, map()} | {:error, term()}
  def client_credentials do
    body = %{grant_type: "client_credentials"}

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{base64_credentials()}"}
    ]

    send_token_request(body, headers)
  end

  @doc """
  Generates a cryptographically random code verifier for PKCE.
  Must be between 43 and 128 characters.
  """
  @spec generate_code_verifier() :: String.t()
  def generate_code_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 128)
  end

  @doc """
  Generates a code challenge from a code verifier using S256 (SHA256).
  """
  @spec generate_code_challenge(String.t()) :: String.t()
  def generate_code_challenge(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generates a random state parameter for CSRF protection.
  """
  @spec generate_state() :: String.t()
  def generate_state do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  # Private helpers

  @spec send_token_request(map(), [{String.t(), String.t()}]) ::
          {:ok, map()} | {:error, term()}
  defp send_token_request(body, headers) do
    encoded_body = URI.encode_query(body)

    [
      method: :post,
      url: @token_url,
      headers: headers,
      body: encoded_body
    ]
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: %{"error" => error, "error_description" => desc}}} ->
        {:error, {status, "#{error}: #{desc}"}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec base64_credentials() :: String.t()
  defp base64_credentials do
    client_id = get_client_id()
    client_secret = get_client_secret()

    Base.encode64("#{client_id}:#{client_secret}")
  end

  @spec get_client_id() :: String.t()
  defp get_client_id do
    Application.get_env(:lux, :twitter)[:client_id] ||
      System.get_env("TWITTER_CLIENT_ID") ||
      raise "Twitter client_id not configured. Set config :lux, :twitter, client_id: \"...\" or TWITTER_CLIENT_ID env var"
  end

  @spec get_client_secret() :: String.t()
  defp get_client_secret do
    Application.get_env(:lux, :twitter)[:client_secret] ||
      System.get_env("TWITTER_CLIENT_SECRET") ||
      raise "Twitter client_secret not configured. Set config :lux, :twitter, client_secret: \"...\" or TWITTER_CLIENT_SECRET env var"
  end

  @spec get_redirect_uri() :: String.t()
  defp get_redirect_uri do
    Application.get_env(:lux, :twitter)[:redirect_uri] ||
      System.get_env("TWITTER_REDIRECT_URI") ||
      "http://localhost:4000/callback"
  end
end
