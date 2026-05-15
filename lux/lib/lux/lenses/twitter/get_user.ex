defmodule Lux.Lenses.Twitter.GetUser do
  @moduledoc """
  Lens for fetching a Twitter user by username or ID.

  ## Examples

      GetUser.focus(%{username: "elonmusk"})
      GetUser.focus(%{user_id: "1234567890"})
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter User",
    description: "Fetches a Twitter user profile by username or ID",
    url: "https://api.twitter.com/2/users/:id_placeholder",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        username: %{type: :string, description: "Twitter username (without @)"},
        user_id: %{type: :string, description: "Twitter user ID (alternative to username)"},
        "user.fields": %{
          type: :string,
          description: "Comma-separated list of user fields",
          default: "name,username,profile_image_url,public_metrics,description,verified,created_at"
        }
      }
    }

  @impl true
  def before_focus(params) do
    cond do
      Map.has_key?(params, :username) ->
        params
        |> Map.delete(:username)
        |> Map.put(:url, "https://api.twitter.com/2/users/by/username/" <> params[:username])

      Map.has_key?(params, :user_id) ->
        params
        |> Map.delete(:user_id)
        |> Map.put(:url, "https://api.twitter.com/2/users/" <> params[:user_id])

      true ->
        params
    end
  end

  @impl true
  def after_focus(%{"data" => user}), do: {:ok, format_user(user)}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}

  defp format_user(user) do
    %{
      id: user["id"],
      name: user["name"],
      username: user["username"],
      description: user["description"],
      profile_image_url: user["profile_image_url"],
      verified: user["verified"],
      public_metrics: user["public_metrics"],
      created_at: user["created_at"]
    }
  end
end
