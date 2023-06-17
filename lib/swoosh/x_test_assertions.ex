defmodule Swoosh.X.TestAssertions do
  @moduledoc ~S"""
  Experimental New TestAssertions Module that may replace the old new in v2.

  This module contains a set of assertions functions that you can import in your
  test cases.

  It is meant to be used with the
  [Swoosh.Adapters.Test](Swoosh.Adapters.Test.html) module.

  **Note**: `Swoosh.X.TestAssertions` works for unit tests and basic integration tests.
  Unfortunately it's not going to work for feature/E2E tests.
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

  @doc """
  Sets Swoosh test adapter to global mode.

  In global mode, emails are consumed by the current test process,
  doesn't matter which process sent it.

  An ExUnit case where tests use Swoosh in global mode cannot be `async: true`.

  ## Examples

      defmodule MyTest do
        use ExUnit.Case, async: false

        import Swoosh.Email
        import Swoosh.X.TestAssertions

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
  @spec assert_email_sent() :: boolean | no_return
  def assert_email_sent do
    refute Enum.empty?(emails()), "Expected any emails to be sent but none were present"
  end

  @spec assert_email_sent(Email.t() | Keyword.t() | (Email.t() -> boolean())) ::
          boolean | no_return

  @doc ~S"""
  Asserts `email` was sent.

  You can pass a keyword list to match on specific params
  or an anonymous function that returns a boolean.

  ## Examples

      iex> alias Swoosh.Email
      iex> import Swoosh.X.TestAssertions

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
    matches? = &match?(^email, &1)
    emails = emails()

    assert Enum.any?(emails, matches?), """
    Expected

    #{inspect(emails, pretty: true)}

    to contain email

    #{inspect(email, pretty: true)}

    but no email matched
    """
  end

  def assert_email_sent(attributes) when is_list(attributes) do
    has_attributes? = fn email -> Enum.all?(attributes, &has?(email, &1)) end
    emails = emails()

    assert Enum.any?(emails, has_attributes?), """
    Expected

    #{inspect(emails, pretty: true)}

    to contain email with attributes

    #{inspect(attributes, pretty: true)}

    but none matched
    """
  end

  def assert_email_sent(predicate) when is_function(predicate, 1) do
    emails = emails()

    assert Enum.any?(emails, predicate), """
    Expected 

    #{inspect(emails, pretty: true)}

    to contain matching email but none matched
    """
  end

  defp has?(email, {:subject, value}),
    do: email.subject == value

  defp has?(email, {:from, value}),
    do: email.from == Recipient.format(value)

  defp has?(email, {:reply_to, value}),
    do: email.reply_to == Recipient.format(value)

  defp has?(email, {:to, value}) when is_list(value),
    do: email.to == Enum.map(value, &Recipient.format/1)

  defp has?(email, {:to, value}),
    do: Recipient.format(value) in email.to

  defp has?(email, {:cc, value}) when is_list(value),
    do: email.cc == Enum.map(value, &Recipient.format/1)

  defp has?(email, {:cc, value}),
    do: Recipient.format(value) in email.cc

  defp has?(email, {:bcc, value}) when is_list(value),
    do: email.bcc == Enum.map(value, &Recipient.format/1)

  defp has?(email, {:bcc, value}),
    do: Recipient.format(value) in email.bcc

  defp has?(email, {:text_body, %Regex{} = value}),
    do: email.text_body =~ value

  defp has?(email, {:text_body, value}),
    do: email.text_body == value

  defp has?(email, {:html_body, %Regex{} = value}),
    do: email.html_body =~ value

  defp has?(email, {:html_body, value}),
    do: email.html_body == value

  defp has?(email, {:headers, value}),
    do: email.headers == value

  @doc ~S"""
  Asserts no emails were sent.
  """
  @spec refute_email_sent() :: boolean | no_return
  def refute_email_sent() do
    emails = emails()

    assert Enum.empty?(emails), """
    Expected no emails to be sent but those emails were present

    #{inspect(emails, pretty: true)}
    """
  end

  @spec refute_email_sent(Email.t() | list | (Email.t() -> boolean)) :: boolean | no_return
  @doc ~S"""
  Asserts email with `attributes` was not sent.

  You can pass a keyword list to match on specific params
  or an anonymous function that returns a boolean.
  """
  def refute_email_sent(%Email{} = email) do
    matches? = &match?(^email, &1)
    emails = emails()

    matched_email = Enum.find(emails, matches?)

    refute matched_email, """
    Expected

    #{inspect(emails, pretty: true)}

    to not contain

    #{inspect(email, pretty: true)}

    but this email matched

    #{inspect(matched_email, pretty: true)}
    """
  end

  def refute_email_sent(attributes) when is_list(attributes) do
    has_attributes? = fn email -> Enum.all?(attributes, &has?(email, &1)) end
    emails = emails()

    matched_email = Enum.find(emails, has_attributes?)

    refute matched_email, """
    Expected

    #{inspect(emails, pretty: true)}

    to not contain email with attributes

    #{inspect(attributes, pretty: true)}

    but this email matched

    #{inspect(matched_email, pretty: true)}
    """
  end

  def refute_email_sent(predicate) when is_function(predicate, 1) do
    emails = emails()

    matched_email = Enum.find(emails, predicate)

    refute matched_email, """
    Expected

    #{inspect(emails, pretty: true)}

    to not contain matching email but this email matched

    #{inspect(matched_email, pretty: true)}
    """
  end

  @doc """
  Removes and returns from mailbox all sent emails.
  """
  @spec flush_emails() :: list(Email.t())
  def flush_emails do
    do_flush_emails([])
  end

  defp do_flush_emails(emails) do
    receive do
      {:email, email} -> do_flush_emails([email | emails])
    after
      0 -> emails
    end
  end

  defp emails() do
    emails = flush_emails()

    Enum.each(emails, &send(self(), {:email, &1}))

    emails
  end
end
