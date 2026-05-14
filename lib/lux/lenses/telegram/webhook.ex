defmodule Lux.Lenses.TelegramLens.Webhook do
  @moduledoc """
  Webhook server for receiving Telegram updates.

  This module provides a Plug-based webhook endpoint that receives
  updates from Telegram and dispatches them to a configured handler.

  ## Usage

      plug Lux.Lenses.TelegramLens.Webhook,
        handler: {MyBot, :handle_update},
        secret: System.get_env("TELEGRAM_SECRET")

  ## Security

  All incoming requests are validated using the HMAC signature
  sent by Telegram in the `X-Telegram-Bot-Api-Secret-Token` header.

  ## Configuration

  Set your secret token in config:

      config :lux, :telegram,
        webhook_secret: "my_webhook_secret"
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts) do
    handler = Keyword.fetch!(opts, :handler)
    secret = Keyword.get(opts, :secret, Application.get_env(:lux, :telegram, [])[:webhook_secret])
    path = Keyword.get(opts, :path, "/telegram/webhook")

    %{
      handler: handler,
      secret: secret,
      path: path
    }
  end

  @impl true
  def call(%Plug.Conn{method: "POST", path_info: path_info} = conn, %{path: path} = config) do
    if List.starts_with?(path_info, path_segments(path)) do
      do_webhook(conn, config)
    else
      conn
    end
  end

  def call(conn, _config), do: conn

  defp do_webhook(conn, config) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, update} <- Jason.decode(body),
         :ok <- validate_secret(conn, config),
         :ok <- dispatch_update(update, config) do
      send_resp(conn, 200, "ok")
    else
      {:error, :invalid_signature} ->
        send_resp(conn, 401, "unauthorized")

      {:error, :invalid_payload} ->
        send_resp(conn, 400, "bad request")

      {:error, reason} ->
        Logger.error("Webhook error: #{inspect(reason)}")
        send_resp(conn, 500, "internal error")
    end
  end

  defp validate_secret(%Plug.Conn{} = conn, %{secret: nil}) do
    :ok
  end

  defp validate_secret(%Plug.Conn{} = conn, %{secret: secret}) do
    received = get_req_header(conn, "x-telegram-bot-api-secret-token") |> List.first()

    if valid_signature?(secret, received) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp valid_signature?(_secret, nil), do: false
  defp valid_signature?(secret, token) do
    :crypto.hmac(:sha256, secret, token) == token
  rescue
    _ -> false
  end

  defp dispatch_update(update, %{handler: {mod, fun}}) do
    try do
      apply(mod, fun, [update])
      :ok
    rescue
      e ->
        Logger.error("Handler error: #{inspect(e)}")
        {:error, e}
    end
  end

  defp path_segments("/" <> path) do
    String.split(path, "/", trim: true)
  end

  defp path_segments(path) do
    String.split(path, "/", trim: true)
  end
end
