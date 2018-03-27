defmodule Swoosh.Email.Format do
  @moduledoc false

  def format_recipient({name, address} = recipient) when is_binary(name) and is_binary(address) do
    recipient
  end

  def format_recipient(recipient) when is_binary(recipient) and recipient != "" do
    {"", recipient}
  end

  def format_recipient(invalid) do
    raise ArgumentError,
      message: """
      The recipient `#{inspect(invalid)}` is invalid.

      Recipients must be a string representing an email address like
      `foo.bar@example.com` or a two-element tuple `{name, address}`, where
      name and address are strings.
      """
  end
end
