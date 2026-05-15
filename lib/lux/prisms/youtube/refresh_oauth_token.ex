defmodule Lux.Prisms.YouTube.RefreshOAuthToken do
  @moduledoc "Refresh the YouTube OAuth2 access token."
  use Lux.Prism,
    name: "YouTube Refresh OAuth Token",
    description: "Refreshes the OAuth2 access token using the stored refresh token.",
    input_schema: %{
      type: :object,
      properties: %{
        refresh_token: %{type: :string, description: "OAuth2 refresh token"}
      },
      required: ["refresh_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        expires_in: %{type: :integer},
        token_type: %{type: :string}
      }
    }

  @impl true
  def handler(%{"refresh_token" => refresh_token}, _ctx) do
    client_id = Lux.Config.youtube_client_id()
    client_secret = Lux.Config.youtube_client_secret()

    body = URI.encode_query(%{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    })

    req_body = body |> String.replace("\n", "") |> String.replace(" ", "")
    req = HTTPoison.post!(
      "https://oauth2.googleapis.io/token",
      req_body,
      [{"Content-Type", "application/x-www-form-urlencoded"}]
    )

    case req.status_code do
      200 ->
        j = Jason.decode!(req.body)
        {:ok, %{
          access_token: j["access_token"],
          expires_in: j["expires_in"],
          token_type: j["token_type"]
        }}
      _ ->
        {:error, "Token refresh failed: #{req.status_code}"}
    end
  end
end
