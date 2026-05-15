defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Twitter API v2 integration for the Lux framework.

  Provides common settings, authentication headers, and request configuration
  for all Twitter lenses and prisms. Uses OAuth 2.0 Bearer Token authentication
  with support for both app-only and user-context tokens.
  """

  alias Lux.Integrations.Twitter.Client

  @doc """
  Returns the default request settings for Twitter API calls.
  Includes headers and custom authentication function.
  """
  @spec request_settings() :: %{headers: [{String.t(), String.t()}], auth: map()}
  def request_settings do
    %{
      headers: headers(),
      auth: auth()
    }
  end

  @doc """
  Returns common HTTP headers for Twitter API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "LuxTwitterIntegration/1.0"}
    ]
  end

  @doc """
  Returns the authentication configuration.
  Uses a custom auth function that adds the Bearer token header.
  """
  @spec auth() :: %{type: :custom, auth_function: fun()}
  def auth do
    %{type: :custom, auth_function: &__MODULE__.add_auth_header/1}
  end

  @doc """
  Adds the Authorization Bearer header to the request.
  Accepts either a Lens struct or a connection map and merges
  the auth header into the existing headers.

  ## Parameters

    - lens_or_conn - A Lens struct or map with a `:headers` key

  ## Returns

    - Updated map with Authorization header added
  """
  @spec add_auth_header(map()) :: map()
  def add_auth_header(lens_or_conn) do
    token = get_bearer_token()
    auth_header = {"Authorization", "Bearer #{token}"}

    headers =
      lens_or_conn
      |> Map.get(:headers, [])
      |> Kernel.++([auth_header])

    Map.put(lens_or_conn, :headers, headers)
  end

  @doc """
  Retrieves the bearer token from application config.
  Falls back to environment variable TWITTER_BEARER_TOKEN.
  """
  @spec get_bearer_token() :: String.t() | nil
  def get_bearer_token do
    Application.get_env(:lux, :api_keys)[:twitter] ||
      System.get_env("TWITTER_BEARER_TOKEN")
  end

  @doc """
  Retrieves the authenticated user ID from application config.
  Required for user-context operations (like, retweet, follow, etc.).
  """
  @spec get_user_id() :: String.t() | nil
  def get_user_id do
    Application.get_env(:lux, :twitter)[:user_id] ||
      System.get_env("TWITTER_USER_ID")
  end

  @doc """
  Makes an authenticated request through the Twitter client.
  Convenience function that delegates to `Lux.Integrations.Twitter.Client.request/3`.
  """
  @spec request(atom(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    Client.request(method, path, opts)
  end
end
