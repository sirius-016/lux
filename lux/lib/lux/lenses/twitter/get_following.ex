defmodule Lux.Lenses.Twitter.GetFollowing do
  @moduledoc """
  Lens for fetching users that a user is following.
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Following",
    description: "Fetches users that the specified user is following",
    url: "https://api.twitter.com/2/users/:user_id/following",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "User ID"},
        max_results: %{type: :integer, description: "Max results (1-1000)", default: 100},
        pagination_token: %{type: :string, description: "Next page token"},
        "user.fields": %{
          type: :string,
          description: "User fields",
          default: "name,username,profile_image_url,public_metrics,verified"
        }
      },
      required: ["user_id"]
    }

  @impl true
  def before_focus(params) do
    user_id = params[:user_id]
    params
    |> Map.delete(:user_id)
    |> Map.put(:url, "https://api.twitter.com/2/users/" <> user_id <> "/following")
  end

  @impl true
  def after_focus(%{"data" => users, "meta" => meta}) do
    {:ok, %{users: users, meta: meta}}
  end

  def after_focus(%{"data" => users}), do: {:ok, %{users: users, meta: %{}}}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(body), do: {:ok, body}
end
