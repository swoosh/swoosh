defmodule Swoosh.TestAssertions do
  @moduledoc ~S"""
  This module contains a set of assertions functions that you can import in your
  test cases.

  It is meant to be used with the
  [Swoosh.Adapters.Test](Swoosh.Adapters.Test.html) module.

  **Note**: `Swoosh.TestAssertions` works for unit tests and basic integration tests.
  Unfortunately, it's not going to work for feature/E2E tests.
  The mechanism of `assert_email_sent` is based on messaging sending between processes,
  and is expecting the calling process (the one that calls `assert_email_sent`) to be
  the calling process of `Mailer.deliver`, or be the parent process of the whatever
  does the `Mailer.deliver` call.

  For feature/E2E tests, you should use `Swoosh.Adapters.Local` adapter.
  In your test, instead of calling `assert_email_sent`, you should navigate to the
  preview url with your E2E tool (e.g. `wallaby`) and test that the email is in the inbox.
  """

  import ExUnit.Assertions

  alias Swoosh.Email
  alias Swoosh.Email.Recipient

  @type email_assertion :: Email.t() | Keyword.t() | (Email.t() -> boolean())

  @doc """
  Sets Swoosh test adapter to global mode.

  In global mode, emails are consumed by the current test process,
  doesn't matter which process sent it.

  An ExUnit case where tests use Swoosh in global mode cannot be `async: true`.

  ## Examples

      defmodule MyTest do
        use ExUnit.Case, async: false

        import Swoosh.Email
        import Swoosh.TestAssertions

        setup :set_swoosh_global

        test "it sends email" do
          # ...
          assert_email_sent(subject: "Hi Avengers!")
        end
      end
  """
  def set_swoosh_global(context \\ %{}) do
    if Map.get(context, :async) do
      raise "Swoosh cannot be set to global mode when the ExUnit case is async. " <>
              "If you want to use Swoosh in global mode, remove \"async: true\" when using ExUnit.Case"
    else
      Application.put_env(:swoosh, :shared_test_process, self())

      ExUnit.Callbacks.on_exit(fn ->
        Application.delete_env(:swoosh, :shared_test_process)
      end)

      :ok
    end
  end

  @doc ~S"""
  Asserts any email was sent.
  """
  @spec assert_email_sent() :: tuple | no_return
  def assert_email_sent do
    assert_received {:email, _}
  end

  @spec assert_email_sent(email_assertion()) ::
          :ok | tuple | no_return

  @doc ~S"""
  Asserts `email` was sent.

  You can pass a keyword list to match on specific params
  or an anonymous function that returns a boolean.

  ## Examples

      iex> alias Swoosh.Email
      iex> import Swoosh.TestAssertions

      iex> email = Email.new(subject: "Hello, Avengers!")
      iex> Swoosh.Adapters.Test.deliver(email, [])

      # assert a specific email was sent
      iex> assert_email_sent(email)

      # assert an email with specific field(s) was sent
      iex> assert_email_sent(subject: "Hello, Avengers!")

      # assert an email that satisfies a condition
      iex> assert_email_sent(fn email ->
      ...>   assert length(email.to) == 2
      ...> end)
  """
  def assert_email_sent(%Email{} = email) do
    assert_received {:email, ^email}
  end

  def assert_email_sent(params) when is_list(params) do
    assert_received {:email, email}
    Enum.each(params, &assert_equal(email, &1))
  end

  def assert_email_sent(fun) when is_function(fun, 1) do
    assert_received {:email, email}
    assert fun.(email)
  end

  @doc ~S"""
  Asserts multiple emails were sent.

  You can pass a list of maps to match on specific params per email

  ## Examples

      iex> alias Swoosh.Email
      iex> import Swoosh.TestAssertions

      iex> emails = Enum.map(1..2, fn n -> Email.new(subject: "Hello, Avengers #{n}!") end)
      iex> Swoosh.Adapters.Test.deliver_many(emails, [])

      # assert a specific email was sent
      iex> assert_emails_sent(emails)

      # assert the list of emails with specific field(s) that were sent
      iex> assert_email_sent([
        %{subject: "Hello, Avengers 1!"},
        %{subject: "Hello, Avengers 2!"},
      ])
  """
  @spec assert_emails_sent() :: tuple | no_return
  def assert_emails_sent do
    assert_receive {:emails, _}
  end

  @spec assert_emails_sent([email_assertion()]) ::
          :ok | tuple | no_return
  def assert_emails_sent([%Swoosh.Email{} | _] = emails) do
    assert_received {:emails, ^emails}
  end

  def assert_emails_sent([%{} | _] = params_map_list) do
    assert_received {:emails, emails}

    assert length(emails) == length(params_map_list)

    emails
    |> Enum.zip(params_map_list)
    |> Enum.each(fn {email, params_map} ->
      Enum.each(params_map, &assert_equal(email, &1))
    end)
  end

  defp assert_equal(email, {:subject, %Regex{} = value}),
    do: assert(email.subject =~ value)

  defp assert_equal(email, {:subject, value}),
    do: assert(email.subject == value)

  defp assert_equal(email, {:from, value}),
    do: assert(email.from == Recipient.format(value))

  defp assert_equal(email, {:reply_to, value}),
    do: assert(email.reply_to == Recipient.format(value))

  defp assert_equal(email, {:to, value}) when is_list(value),
    do: assert(email.to == Enum.map(value, &Recipient.format/1))

  defp assert_equal(email, {:to, value}),
    do: assert(Recipient.format(value) in email.to)

  defp assert_equal(email, {:cc, value}) when is_list(value),
    do: assert(email.cc == Enum.map(value, &Recipient.format/1))

  defp assert_equal(email, {:cc, value}),
    do: assert(Recipient.format(value) in email.cc)

  defp assert_equal(email, {:bcc, value}) when is_list(value),
    do: assert(email.bcc == Enum.map(value, &Recipient.format/1))

  defp assert_equal(email, {:bcc, value}),
    do: assert(Recipient.format(value) in email.bcc)

  defp assert_equal(email, {:text_body, %Regex{} = value}),
    do: assert(email.text_body =~ value)

  defp assert_equal(email, {:text_body, value}),
    do: assert(email.text_body == value)

  defp assert_equal(email, {:html_body, %Regex{} = value}),
    do: assert(email.html_body =~ value)

  defp assert_equal(email, {:html_body, value}),
    do: assert(email.html_body == value)

  defp assert_equal(email, {:headers, value}),
    do: assert(email.headers == value)

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
    quote do
      refute_email_sent(%{unquote_splicing(Enum.map(attributes, &email_pattern/1))})
    end
  end

  defmacro refute_email_sent(pattern) do
    quote do
      refute_received {:email, unquote(pattern)}
    end
  end

  defp email_pattern({key, value}) when key in [:from, :reply_to] do
    {key, Recipient.format(value)}
  end

  defp email_pattern({key, value}) when key in [:to, :cc, :bcc] do
    {key, value |> List.wrap() |> Enum.map(&Recipient.format/1)}
  end

  defp email_pattern({key, value}) do
    {key, value}
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
