defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour that all LLM providers must implement, plus helpers for
  working with providers as first-class values.

  Each provider declares its capabilities and the models it supports
  together with cost and context-window metadata.
  """

  @type model_info :: %{
          id: String.t(),
          context_window: pos_integer(),
          input_cost: float(),
          output_cost: float()
        }

  @type provider_metadata :: %{
          name: String.t(),
          models: [model_info()],
          capabilities: [:tools | :vision | :streaming]
        }

  @callback call(prompt :: String.t() | [map()], tools :: [map()], opts :: keyword()) ::
              {:ok, Lux.LLM.Response.t()} | {:error, String.t()}

  @callback metadata() :: provider_metadata()

  @callback health_check() :: :ok | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.LLM.Provider

      def metadata do
        %{name: __MODULE__ |> Module.split() |> List.last(), models: [], capabilities: [:tools, :streaming]}
      end

      def health_check do
        :ok
      end

      defoverridable metadata: 0, health_check: 0
    end
  end

  @spec name(module()) :: String.t()
  def name(module), do: module.metadata()[:name]

  @spec capabilities(module()) :: [:tools | :vision | :streaming]
  def capabilities(module), do: module.metadata()[:capabilities]

  @spec models(module()) :: [model_info()]
  def models(module), do: module.metadata()[:models]

  @spec model!(String.t(), pos_integer(), float(), float()) :: model_info()
  def model!(id, context_window, input_cost, output_cost) do
    %{id: id, context_window: context_window, input_cost: input_cost, output_cost: output_cost}
  end

  @spec known_providers() :: [module()]
  def known_providers do
    [Lux.LLM.OpenAI, Lux.LLM.Anthropic, Lux.LLM.TogetherAI, Lux.LLM.Mira]
  end
end
