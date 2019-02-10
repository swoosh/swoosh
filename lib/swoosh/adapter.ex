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
  @type email :: Email.t()
  @type config :: Keyword.t()

  @doc """
  Delivers an email with the given config.
  """
  @callback deliver(email, config) :: {:ok, term} | {:error, term}

  @callback validate_config(config) :: :ok | no_return
  @callback validate_dependency() :: :ok | [module | {atom, module}]

  @optional_callbacks validate_dependency: 0

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
