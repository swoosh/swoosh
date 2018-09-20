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
  Asserts any email was sent.
  """
  @spec assert_email_sent() :: true | no_return
  def assert_email_sent do
    assert_received {:email, _}
  end

  @spec assert_email_sent(Email.t() | Keyword.t()) :: true | no_return

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
    Enum.each(params, &assert_equal(email, &1))
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
  Asserts no emails were sent.
  """
  defmacro refute_email_sent() do
    quote do
      refute_received {:email, _}
    end
  end

  @doc ~S"""
  Asserts email with `attributes` was not sent.

  Performs pattern matching using the given pattern, equivalent to `pattern = email`.
  
  When a list of attributes is given, they will be converted to a pattern.

  It converts list fields (`:to`, `:cc`, `:bcc`) to a single element list if a single value is
  given (`to: "email@example.com"` => `to: ["email@example.com"]`).

  After conversion, performs pattern matching using a map of email attributes, similar to
  `%{attributes...} = email`.
  """
  defmacro refute_email_sent(attributes) when is_list(attributes) do
    expr = attributes |> email_pattern() |> Macro.escape()

    quote do
      refute_email_sent(unquote(expr))
    end
  end

  defmacro refute_email_sent(pattern) do
    quote do
      refute_received {:email, unquote(pattern)}
    end
  end

  defp email_pattern(attributes) when is_list(attributes) do
    Enum.reduce(attributes, %{}, &email_pattern(&2, &1))
  end

  defp email_pattern(%{} = pattern, {key, value}) when key in [:from, :reply_to] do
    Map.put(pattern, key, format_recipient(value))
  end

  defp email_pattern(%{} = pattern, {key, value}) when key in [:to, :cc, :bcc] do
    Map.put(pattern, key, value |> List.wrap() |> Enum.map(&format_recipient/1))
  end

  defp email_pattern(%{} = pattern, {key, value}) do
    Map.put(pattern, key, value)
  end

  @doc ~S"""
  Asserts no emails were sent.
  """
  @spec assert_no_email_sent() :: false | no_return
  def assert_no_email_sent() do
    refute_email_sent()
  end

  @doc ~S"""
  Asserts `email` was not sent.

  Performs exact matching of the email struct.
  """
  @spec assert_email_not_sent(Email.t()) :: false | no_return
  def assert_email_not_sent(%Email{} = email) do
    refute_email_sent(^email)
  end
end
