defmodule Swoosh.DeliveryError do
  defexception [reason: nil, payload: nil]

  def message(exception) do
    formatted = format_error(exception.reason, exception.payload)
    "delivery error: #{formatted}"
  end

  defp format_error(:from_not_set, _), do: "expected \"from\" to be set"
  defp format_error(:invalid_email, _), do: "expected %Swoosh.Email{}"
  defp format_error(:unsupported_feature, feature), do: "#{feature} not supported for this adapter"
  defp format_error(:api_error, {code, body}), do: "api error - response code: #{code}. body: #{body}"
  defp format_error(:smtp_error, {type, message}), do: "smtp error - type: #{type}. message: #{message}"
  defp format_error(reason, _), do: "#{inspect reason}"
end
