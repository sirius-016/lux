defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client for YouTube Data API v3.

  Supports two auth modes:
  - API Key (public read): key is passed as query param
  - OAuth2 Token (authenticated): token is added as Authorization header
  """

  require Logger

  @endpoint "https://www.googleapis.com/youtube/v3"

  @type request_opts :: %{
    optional(:api_key) => String.t(),
    optional(:access_token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:plug) => {module(), term()}
  }

  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ \%{}) do
    url = @endpoint <> path
    api_key = opts[:api_key] || Lux.Config.youtube_api_key()
    access_token = opts[:access_token] || Lux.Config.youtube_access_token()

    headers = [{"Content-Type", "application/json"}]
    headers = if access_token do
      [{"Authorization", "Bearer #{access_token}"} | headers]
    else
      headers
    end

    params = if api_key, do: Map.put(opts[:params] || %{}, "key", api_key), else: opts[:params] || %{}

    req_options = [
      method: method,
      url: url,
      headers: headers
    ]

    req_options = if map_size(params) > 0, do: Keyword.merge(req_options, [params: params]), else: req_options
    req_options = if opts[:json], do: Keyword.merge(req_options, [json: opts[:json]]), else: req_options
    req_options = if opts[:plug], do: Keyword.merge(req_options, [plug: opts[:plug]]), else: req_options

    req_options
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: %{"error" => %{"errors" => errors}}}} ->
        {:error, {status, List.first(errors)["reason"] || "api_error"}}

      {:ok, %{status: status, body: %{"error" => %{"message" => msg}}}} ->
        {:error, {status, msg}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
