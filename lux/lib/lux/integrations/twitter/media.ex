defmodule Lux.Integrations.Twitter.Media do
  @moduledoc """
  Chunked media upload for Twitter API.

  Supports uploading images, GIFs, and videos using Twitter's chunked upload API.
  Large files are split into 5MB chunks and uploaded sequentially.

  ## Usage

      {:ok, media_id} = Media.upload(token, file_path, "image/png")
      {:ok, media_id} = Media.upload(token, video_path, "video/mp4")
  """

  alias Lux.Integrations.Twitter.Client

  @upload_endpoint "https://upload.twitter.com/1.1/media/upload"
  @chunk_size 5 * 1024 * 1024  # 5MB

  @doc "Uploads a media file to Twitter."
  @spec upload(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def upload(token, file_path, content_type) do
    with {:ok, file_size} <- File.stat(file_path),
         {:ok, media_id} <- init_upload(token, file_size.size, content_type),
         :ok <- append_chunks(token, media_id, file_path),
         {:ok, _} <- finalize_upload(token, media_id) do
      {:ok, media_id}
    end
  end

  @spec init_upload(String.t(), non_neg_integer(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defp init_upload(token, total_bytes, content_type) do
    body = URI.encode_query(%{
      "command" => "INIT",
      "total_bytes" => to_string(total_bytes),
      "media_type" => content_type
    })

    req_opts = %{
      token: token,
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}]
    }

    case Client.request(:post, "", Map.put(req_opts, :json, nil)) do
      {:ok, _} ->
        # INIT uses form encoding, make direct request
        headers = [{"Authorization", "OAuth2 Bearer #{token}"}]
        case Req.post(@upload_endpoint, headers: headers, body: body) do
          {:ok, %{status: 200, body: %{"media_id_string" => media_id}}} ->
            {:ok, media_id}
          {:ok, %{body: body}} ->
            {:error, body}
          {:error, error} ->
            {:error, error}
        end
      {:error, error} ->
        {:error, error}
    end
  end

  @spec append_chunks(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  defp append_chunks(token, media_id, file_path) do
    with {:ok, content} <- File.read(file_path) do
      chunks = chunk_binary(content, @chunk_size)
      total = length(chunks)

      Enum.reduce_while(Enum.with_index(chunks), :ok, fn {chunk, index}, _acc ->
        body = URI.encode_query(%{
          "command" => "APPEND",
          "media_id" => media_id,
          "segment_index" => to_string(index),
          "media_data" => Base.encode64(chunk)
        })

        headers = [{"Authorization", "OAuth2 Bearer #{token}"},
                    {"Content-Type", "application/x-www-form-urlencoded"}]

        case Req.post(@upload_endpoint, headers: headers, body: body) do
          {:ok, %{status: 204}} -> {:cont, :ok}
          {:ok, %{body: resp}} -> {:halt, {:error, {:append_failed, index, resp}}}
          {:error, error} -> {:halt, {:error, {:append_failed, index, error}}}
        end
      end)
    end
  end

  @spec finalize_upload(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  defp finalize_upload(token, media_id) do
    body = URI.encode_query(%{
      "command" => "FINALIZE",
      "media_id" => media_id
    })

    headers = [{"Authorization", "OAuth2 Bearer #{token}"},
                {"Content-Type", "application/x-www-form-urlencoded"}]

    case Req.post(@upload_endpoint, headers: headers, body: body) do
      {:ok, %{status: 200} = resp} -> {:ok, resp.body}
      {:ok, %{body: body}} -> {:error, {:finalize_failed, body}}
      {:error, error} -> {:error, error}
    end
  end

  @spec chunk_binary(binary(), non_neg_integer()) :: [binary()]
  defp chunk_binary(binary, chunk_size) do
    do_chunk(binary, chunk_size, [])
  end

  defp do_chunk(<<>>, _size, acc), do: Enum.reverse(acc)
  defp do_chunk(binary, size, acc) when byte_size(binary) > size do
    <<chunk::binary-size(size), rest::binary>> = binary
    do_chunk(rest, size, [chunk | acc])
  end
  defp do_chunk(binary, _size, acc), do: Enum.reverse([binary | acc])
end
