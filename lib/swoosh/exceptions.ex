defmodule Swoosh.AdapterError do
  defexception [:message, :reason, :original]

  def exception(opts) do
    reason = Keyword.fetch!(opts, :reason)
    message = Keyword.get(opts, :message)
    original = Keyword.get(opts, :original)
    message =
      if original do
        """
        #{format_reason(reason)}: #{message}

        Error message retrieved from adapter:

            #{inspect(original)}
        """
      else
        format_reason(reason)
      end

    %__MODULE__{message: message, reason: reason, original: original}
  end

  @doc false
  @spec format_reason(term) :: binary
  def format_reason(reason)

  def format_reason(:bad_request) do
    "bad request: you might be missing a required parameter or your request is malformed"
  end

  def format_reason(:unauthorized) do
    "unauthorized: missing or incorrect API key"
  end

  def format_reason(:not_found) do
    "not found: the resource that you are trying to access does not exist"
  end

  def format_reason(:server_error) do
    "server error: something is wrong on the provider's end"
  end

  def format_reason(reason) do
    to_string(reason)
  end
end

defmodule Swoosh.DeliveryError do
  defexception [reason: nil, payload: nil]

  def exception(opts) do

  end

  def message(exception) do
    formatted = format_error(exception.reason, exception.payload)
    "delivery error: #{formatted}"
  end

  defp format_error(:from_not_set, _), do: "expected \"from\" to be set"
  defp format_error(:invalid_email, _), do: "expected %Swoosh.Email{}"
  defp format_error(:api_error, {code, body}), do: "api error - response code: #{code}. body: #{body}"
  defp format_error(:smtp_error, {type, message}), do: "smtp error - type: #{type}. message: #{message}"
  defp format_error(reason, _), do: "#{inspect reason}"
end
