defmodule Swoosh.Adapter do
  @moduledoc ~S"""
  Specification of the email delivery adapter.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @required_config opts[:required_config] || []
      @required_deps opts[:required_deps] || []

      @behaviour Swoosh.Adapter

      def validate_config(config) do
        Swoosh.Adapter.validate_config(@required_config, config)
      end

      def validate_dependency do
        Swoosh.Adapter.validate_dependency(@required_deps)
      end
    end
  end

  @type t :: module
  @type email :: Swoosh.Email.t()
  @type config :: Keyword.t()

  @doc """
  Delivers an email with the given config.
  """
  @callback deliver(email(), config()) :: {:ok, term} | {:error, term}

  @doc """
  Delivers multiple emails with the given config in one request. Some email providers allow multiple
  messages to be sent in one HTTP request, for example Mailjet and Postmark allow this. Check your
  provider's documentation to see if that is possible, and see the adapter you use to find out whether
  it has been implemented.
  """
  @callback deliver_many(list(email()), config()) ::
              {:ok, list(term)} | {:error, term}

  @callback validate_config(config()) :: :ok | no_return
  @callback validate_dependency() :: :ok | [module | {atom, module}]

  @optional_callbacks validate_dependency: 0, deliver_many: 2

  @spec validate_config([atom], Keyword.t()) :: :ok | no_return
  def validate_config(required_config, config) do
    missing_keys =
      Enum.reduce(required_config, [], fn key, missing_keys ->
        if config[key] in [nil, ""],
          do: [key | missing_keys],
          else: missing_keys
      end)

    raise_on_missing_config(missing_keys, config)
  end

  defp raise_on_missing_config([], _config), do: :ok

  defp raise_on_missing_config(key, config) do
    raise ArgumentError, """
    expected #{inspect(key)} to be set, got: #{inspect(config)}
    """
  end

  @spec validate_dependency([module | {atom, module}]) ::
          :ok | {:error, [module | {:atom | module}]}
  def validate_dependency(required_deps) do
    if Enum.all?(required_deps, fn
         {_lib, module} -> Code.ensure_loaded?(module)
         module -> Code.ensure_loaded?(module)
       end),
       do: :ok,
       else: {:error, required_deps}
  end
end
