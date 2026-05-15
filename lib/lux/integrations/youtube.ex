defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and functions for YouTube Data API v3 integration.
  """

  @doc "Common headers for YouTube API calls."
  def headers, do: [{"Content-Type", "application/json"}]

  @doc "Common auth settings."
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc "Add OAuth2 bearer token to connection."
  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Lux.Config.youtube_access_token() || Lux.Config.youtube_api_key()
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
