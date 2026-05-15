defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs
  and provides a default implementation.

  Also provides the high-level `chat/3` function powered by the
  abstraction layer (Lux.LLM.Manager) for automatic routing, fallback,
  caching, and cost tracking.
  """

  defmodule Response do
    @moduledoc "A response from an LLM."

    @type t :: %__MODULE__{
            content: String.t() | nil,
            tool_calls: [%{type: String.t(), name: String.t(), params: map()}],
            finish_reason: String.t() | nil,
            structured_output: map() | nil
          }

    defstruct content: nil,
              tool_calls: [],
              finish_reason: nil,
              structured_output: nil
  end

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: map() | keyword()

  @callback call(prompt(), tools(), options()) :: {:ok, Response.t()} | {:error, String.t()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  defdelegate call(prompt, tools, options), to: @default_module

  # ── High-level API (abstraction layer) ──

  @doc """
  Send a chat request with automatic provider routing, fallback, and cost tracking.

  Wraps `Lux.LLM.Manager.chat/3`. See its docs for available options.
  """
  @spec chat(String.t() | [map()], tools(), keyword()) :: {:ok, Response.t()} | {:error, String.t()}
  defdelegate chat(prompt, tools \\ [], opts \\ []), to: Lux.LLM.Manager

  @doc "Configure the abstraction layer at runtime."
  @spec configure(keyword()) :: :ok
  defdelegate configure(opts), to: Lux.LLM.Manager

  @doc "Get a usage report across all providers."
  @spec usage_report() :: [map()]
  defdelegate usage_report(), to: Lux.LLM.Manager

  @doc "Get the total estimated cost."
  @spec total_cost() :: float()
  defdelegate total_cost(), to: Lux.LLM.Manager

  @doc "Get cache hit/miss statistics."
  @spec cache_stats() :: map()
  defdelegate cache_stats(), to: Lux.LLM.Manager
end
