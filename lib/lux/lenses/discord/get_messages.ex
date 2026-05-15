defmodule Lux.Lenses.Discord.GetMessages do
  @moduledoc "Fetch messages from a Discord channel."
  use Lux.Lens,
    name: "Discord Get Messages",
    description: "Retrieves messages from a Discord channel with optional filtering.",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The channel ID to fetch messages from"},
        limit: %{type: :integer, description: "Max messages to return (1-100, default 50)", default: 50},
        before: %{type: :string, description: "Get messages before this message ID"},
        after: %{type: :string, description: "Get messages after this message ID"},
        around: %{type: :string, description: "Get messages around this message ID"}
      },
      required: ["channel_id"]
    }

  alias Lux.Integrations.Discord.Client

  @impl true
  def before_focus(%{"channel_id" => channel_id} = params) do
    %{"channel_id" => channel_id}
    |> maybe_add_param("limit", params["limit"])
    |> maybe_add_param("before", params["before"])
    |> maybe_add_param("after", params["after"])
    |> maybe_add_param("around", params["around"])
  end

  defp maybe_add_param(url_params, _key, nil), do: url_params
  defp maybe_add_param(url_params, key, value) do
    Map.put(url_params, key, value)
  end

  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, %{
      messages: Enum.map(messages, &normalize_message/1),
      count: length(messages)
    }}
  end

  def after_focus(%{"message" => msg}), do: after_focus([msg])
  def after_focus(%{"code" => code, "message" => msg}), do: {:error, "#{code}: #{msg}"}

  defp normalize_message(msg) do
    %{
      id: msg["id"],
      channel_id: msg["channel_id"],
      author: %{
        id: msg["author"]["id"],
        username: msg["author"]["username"],
        discriminator: msg["author"]["discriminator"]
      },
      content: msg["content"],
      timestamp: msg["timestamp"],
      edited_timestamp: msg["edited_timestamp"],
      tts: msg["tts"],
      mention_everyone: msg["mention_everyone"],
      embeds: msg["embeds"],
      reactions: msg["reactions"] || []
    }
  end
end
