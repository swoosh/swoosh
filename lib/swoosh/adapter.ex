defmodule Swoosh.Adapter do
  @moduledoc ~S"""
  Specification of the email delivery adapter.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Swoosh.AdapterError

      @required_config opts[:required_config] || []

      @behaviour Swoosh.Adapter

      def validate_config(config) do
        missing_keys = Enum.reduce(@required_config, [], fn(key, missing_keys) ->
          if config[key] in [nil, ""], do: [key | missing_keys], else: missing_keys
        end)
        raise_on_missing_config(missing_keys, config)
      end

      defp raise_on_missing_config([], _config), do: :ok
      defp raise_on_missing_config(key, config) do
        raise ArgumentError, """
        expected #{inspect key} to be set, got: #{inspect config}
        """
      end

      defp code_to_reason(400), do: :bad_request
      defp code_to_reason(401), do: :unauthorized
      # Mailgun decided to use 402 for "Request Failed - Parameters were valid but request failed"
      # According to https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.3
      # 402 is for "Payment Required" and reserved for future use.
      defp code_to_reason(402), do: :bad_request
      defp code_to_reason(404), do: :not_found
      defp code_to_reason(405), do: :method_not_allowed
      defp code_to_reason(409), do: :conflict
      defp code_to_reason(413), do: :payload_too_large
      defp code_to_reason(415), do: :unsupported_media_type
      defp code_to_reason(422), do: :unprocessable_entity
      defp code_to_reason(429), do: :too_many_requests
      defp code_to_reason(code) when code > 499, do: :server_error
    end
  end

  @type t :: module

  @type email :: Email.t

  @typep config :: Keyword.t

  @doc """
  Delivers an email with the given config.
  """
  @callback deliver(email, config) :: {:ok, term} | {:error, term}

  @callback format_error(term) :: binary
end
