defmodule Swoosh.TestAssertions do
  @moduledoc ~S"""
  This module contains a set of assertions functions that you can import in your
  test cases.

  It is meant to be used with the
  [Swoosh.Adapters.Test](Swoosh.Adapters.Test.html) module.
  """

  import ExUnit.Assertions
  import Swoosh.Email.Format

  alias Swoosh.Email

  @doc ~S"""
  Asserts `email` was sent.

  You pass a keyword list to match on specific params.

  ## Examples

      iex> alias Swoosh.Email
      iex> import Swoosh.TestAssertions

      iex> email = Email.new(subject: "Hello, Avengers!")
      iex> Swoosh.Adapters.Test.deliver(email, [])

      # assert a specific email was sent
      iex> assert_email_sent email

      # assert an email with specific field(s) was sent
      iex> assert_email_sent subject: "Hello, Avengers!"
  """
  def assert_email_sent(%Email{} = email) do
    assert_received {:email, ^email}
  end

  def assert_email_sent(params) when is_list(params) do
    assert_received {:email, email}
    Enum.each(params, fn param -> assert_equal(email, param) end)
  end

  defp assert_equal(email, {:subject, value}), do: assert(email.subject == value)
  defp assert_equal(email, {:from, value}), do: assert(email.from == format_recipient(value))

  defp assert_equal(email, {:reply_to, value}),
    do: assert(email.reply_to == format_recipient(value))

  defp assert_equal(email, {:to, value}) when is_list(value),
    do: assert(email.to == Enum.map(value, &format_recipient/1))

  defp assert_equal(email, {:to, value}), do: assert(format_recipient(value) in email.to)

  defp assert_equal(email, {:cc, value}) when is_list(value),
    do: assert(email.cc == Enum.map(value, &format_recipient/1))

  defp assert_equal(email, {:cc, value}), do: assert(format_recipient(value) in email.cc)

  defp assert_equal(email, {:bcc, value}) when is_list(value),
    do: assert(email.bcc == Enum.map(value, &format_recipient/1))

  defp assert_equal(email, {:bcc, value}), do: assert(format_recipient(value) in email.bcc)
  defp assert_equal(email, {:text_body, %Regex{} = value}), do: assert(email.text_body =~ value)
  defp assert_equal(email, {:text_body, value}), do: assert(email.text_body == value)
  defp assert_equal(email, {:html_body, %Regex{} = value}), do: assert(email.html_body =~ value)
  defp assert_equal(email, {:html_body, value}), do: assert(email.html_body == value)

  @doc ~S"""
  Asserts `email` was not sent.
  """
  def assert_email_not_sent(email) do
    refute_received {:email, ^email}
  end

  @doc ~S"""
  Asserts no emails were sent.
  """
  def assert_no_email_sent() do
    refute_received {:email, _}
  end
end
