defmodule Lux.Lenses.TelegramLens.Polling do
  @moduledoc """
  Long polling handler for Telegram updates.

  Implements efficient long polling that:
  - Tracks the update offset to avoid duplicate processing
  - Automatically acknowledges processed updates
  - Handles rate limits gracefully
  - Supports graceful shutdown

  ## Usage

      {:ok, pid} = Lux.Lenses.TelegramLens.Polling.start_link(
        handler: {MyBot, :handle_update},
        timeout: 30
      )

  ## Options

  - `:handler` - Module and function to call for each update
  - `:timeout` - Long polling timeout in seconds (default 30)
  - `:limit` - Max updates per poll (default 100)
  - `:allowed_updates` - Types of updates to receive
  """

  use GenServer
  require Logger

  @default_timeout 30
  @default_limit 100
  @default_allowed_updates ["message", "edited_message", "callback_query"]

  @type handler :: {module(), atom()}
  @type state :: %{
    handler: handler,
    offset: integer(),
    timeout: integer(),
    limit: integer(),
    allowed_updates: [String.t()],
    running: boolean()
  }

  # --------------------------------------------------------------------------
  # Client API
  # --------------------------------------------------------------------------

  @doc """
  Start the polling server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Stop the polling server.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  @doc """
  Pause polling (e.g., during maintenance).
  """
  @spec pause(GenServer.server()) :: :ok
  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  @doc """
  Resume polling.
  """
  @spec resume(GenServer.server()) :: :ok
  def resume(pid) do
    GenServer.call(pid, :resume)
  end

  @doc """
  Get current polling state.
  """
  @spec get_state(GenServer.server()) :: map()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # --------------------------------------------------------------------------
  # GenServer Callbacks
  # --------------------------------------------------------------------------

  @impl true
  def init(opts) do
    handler = Keyword.fetch!(opts, :handler)

    state = %{
      handler: handler,
      offset: Keyword.get(opts, :offset, 0),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      limit: Keyword.get(opts, :limit, @default_limit),
      allowed_updates: Keyword.get(opts, :allowed_updates, @default_allowed_updates),
      running: true
    }

    {:ok, state, {:continue, :start_polling}}
  end

  @impl true
  def handle_continue(:start_polling, state) do
    poll_loop(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, %{state | running: false}}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    {:reply, :ok, %{state | running: false}}
  end

  @impl true
  def handle_call(:resume, _from, state) do
    poll_loop(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_loop(state)
    {:noreply, state}
  end

  # --------------------------------------------------------------------------
  # Polling Loop
  # --------------------------------------------------------------------------

  defp poll_loop(%{running: false} = state) do
    :ok
  end

  defp poll_loop(%{running: true} = state) do
    case TelegramLens.get_updates(
           offset: state.offset,
           limit: state.limit,
           timeout: state.timeout,
           allowed_updates: state.allowed_updates
         ) do
      {:ok, updates} when is_list(updates) ->
        new_state = process_updates(updates, state)
        schedule_poll()
        {:noreply, new_state}

      {:error, :rate_limited} ->
        Logger.info("Polling: rate limited, waiting 5s")
        :timer.sleep(5_000)
        schedule_poll()
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Polling error: #{inspect(reason)}, retrying in 5s")
        :timer.sleep(5_000)
        schedule_poll()
        {:noreply, state}
    end
  end

  defp process_updates([], state), do: state

  defp process_updates(updates, state) do
    {max_offset, new_state} =
      Enum.reduce(updates, {state.offset, state}, fn update, {max_off, st} ->
        case dispatch_handler(update, st) do
          :ok ->
            off = max_off
            new_off = max(off, update["update_id"] + 1)
            {new_off, %{st | offset: new_off}}

          :acknowledge ->
            {max_off, st}
        end
      end)

    %{new_state | offset: max_offset}
  end

  defp dispatch_handler(update, %{handler: {mod, fun}}) do
    try do
      case apply(mod, fun, [update]) do
        :ok -> :ok
        :acknowledge -> :acknowledge
        :skip -> :acknowledge
        other ->
          Logger.warning("Unknown handler response: #{inspect(other)}, acknowledging")
          :acknowledge
      end
    rescue
      e ->
        Logger.error("Handler error for update #{update["update_id"]}: #{inspect(e)}")
        :acknowledge
    end
  end

  defp schedule_poll do
    send(self(), :poll)
  end
end
