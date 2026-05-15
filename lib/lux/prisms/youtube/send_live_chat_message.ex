defmodule Lux.Prisms.YouTube.SendLiveChatMessage do
  @moduledoc "Send a message to a YouTube live chat."
  use Lux.Prism,
    name: "YouTube Send Live Chat Message",
    description: "Sends a message to a YouTube live chat session.",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{type: :string, description: "Live chat ID"},
        text: %{type: :string, description: "Message text (max 200 chars)"},
        channel_id: %{type: :string, description: "Required text channel ID"}
      },
      required: ["live_chat_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        text: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(%{"live_chat_id" => id, "text" => text}, _ctx) do
    text = String.slice(text, 0, 200)
    case Client.request(:post, "/liveChat/messages", %{
      json: %{snippet: %{liveChatId: id, type: "textMessageEvent", textMessageDetails: %{messageText: text}}}
    }) do
      {:ok, %{"id" => msg_id}} -> {:ok, %{id: msg_id, text: text}}
      {:error, reason} -> {:error, "Failed to send live chat message: #{inspect(reason)}"}
    end
  end
end
