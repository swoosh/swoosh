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
        missing_keys =
          Enum.reduce(@required_config, [], fn key, missing_keys ->
            if config[key] in [nil, ""], do: [key | missing_keys], else: missing_keys
          end)

        raise_on_missing_config(missing_keys, config)
      end

      defp raise_on_missing_config([], _config), do: :ok

      defp raise_on_missing_config(key, config) do
        raise ArgumentError, """
        expected #{inspect(key)} to be set, got: #{inspect(config)}
        """
      end

      case @required_deps do
        [] ->
          []

        deps ->
          def validate_dependency do
            deps = unquote(deps)

            if Enum.all?(deps, fn
                 {lib, module} -> Code.ensure_loaded?(module)
                 module -> Code.ensure_loaded?(module)
               end),
               do: :ok,
               else: {:error, deps}
          end
      end
    end
  end

  @type t :: module

  @type email :: Email.t()

  @typep config :: Keyword.t()

  @doc """
  Delivers an email with the given config.
  """
  @callback deliver(email, config) :: {:ok, term} | {:error, term}
end
