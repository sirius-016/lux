defmodule Lux.Lenses.YouTube.GetLiveChat do
  @moduledoc "Get messages from a live chat session."
  use Lux.Lens,
    name: "YouTube Get Live Chat Messages",
    description: "Retrieves messages from a YouTube live chat session.",
    url: "https://www.googleapis.com/youtube/v3/liveChat/messages",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{type: :string, description: "Live chat ID"},
        max_results: %{type: :integer, description: "Max messages (1-200)", default: 50}
      },
      required: ["live_chat_id"]
    }

  @impl true
  def before_focus(%{"live_chat_id" => id} = params) do
    p = %{"liveChatId" => id, "part" => "snippet,authorDetails"}
    p = if params["max_results"], do: Map.put(p, "maxResults", params["max_results"]), else: p
    %{"url" => "https://www.googleapis.com/youtube/v3/liveChat/messages", "params" => p}
  end

  @impl true
  def after_focus(%{"items" => items, "polling_interval_millis" => interval}) do
    messages = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      author = item["authorDetails"] || %{}
      %{
        id: item["id"],
        type: snippet["type"],
        published_at: snippet["publishedAt"],
        has_display_content: snippet["hasDisplayContent"],
        display_text: snippet["textMessageDetails"]["messageText"],
        channel_id: author["channelId"],
        channel_title: author["displayName"],
        is_verified: author["isVerified"],
        is_chat_owner: author["isChatOwner"],
        is_chat_moderator: author["isChatModerator"]
      }
    end)
    {:ok, %{messages: messages, polling_interval_ms: interval}}
  end

  def after_focus(%{"error" => %{"message" => msg}}), do: {:error, msg}
end
