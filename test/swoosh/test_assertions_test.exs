defmodule Swoosh.TestAssertionsTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  defp deliver(%Swoosh.Email{} = email) do
    {:ok, _} = Swoosh.Adapters.Test.deliver(email, nil)
    email
  end

  setup do
    email =
      new()
      |> from("tony.stark@example.com")
      |> reply_to("bruce.banner@example.com")
      |> to(["steve.rogers@example.com", "bruce.banner@example.com"])
      |> cc(["natasha.romanoff@example.com", "stephen.strange@example.com"])
      |> bcc("loki.odinson@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("some html")
      |> text_body("some text")
      |> deliver()

    {:ok, email: email}
  end

  test "assert any email sent" do
    assert_email_sent()
  end

  test "assert any email sent with no emails sent" do
    receive do
      _ -> nil
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent()
    end
  end

  test "assert email sent with correct email", %{email: email} do
    assert_email_sent(email)
  end

  test "assert email sent with some content matched by a regex" do
    assert_email_sent(text_body: ~r/some text/, html_body: ~r/html$/)
  end

  test "assert email sent with specific params" do
    assert_email_sent(
      subject: "Hello, Avengers!",
      to: "steve.rogers@example.com"
    )
  end

  test "assert email sent with specific to (list)" do
    assert_email_sent(
      to: ["steve.rogers@example.com", "bruce.banner@example.com"]
    )
  end

  test "assert email sent with wrong subject" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(subject: "Hello, X-Men!")
    end
  end

  test "assert email sent with wrong from" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(from: "thor.odinson@example.com")
    end
  end

  test "assert email sent with wrong to" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(to: "loki.odinson@example.com")
    end
  end

  test "assert email sent with wrong to (list)" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(to: ["steve.rogers@example.com"])
    end
  end

  test "assert email sent with wrong cc" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(cc: "bruce.banner@example.com")
    end
  end

  test "assert email sent with wrong bcc" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent(bcc: "bruce.banner@example.com")
    end
  end

  test "assert email sent with wrong email", %{email: email} do
    wrong_email = new() |> subject("Wrong, Avengers!")

    message =
      """
      No message matching {:email, ^email} after 0ms.
      The following variables were pinned:
        email = #{inspect(wrong_email)}
      Process mailbox:
        {:email, #{inspect(email)}}
      """
      |> String.trim()

    try do
      assert_email_sent(wrong_email)
    rescue
      error in [ExUnit.AssertionError] ->
        assert message == error.message
    end
  end

  test "assert email not sent with unexpected email" do
    unexpected_email = new() |> subject("Testing Avenger")
    assert_email_not_sent(unexpected_email)
  end

  test "assert email not sent with expected email", %{email: email} do
    message =
      "Unexpectedly received message {:email, #{inspect(email)}} (which matched {:email, ^email})"

    try do
      assert_email_not_sent(email)
    rescue
      error in [ExUnit.AssertionError] ->
        assert message, error.message
    end
  end

  test "assert no email sent" do
    receive do
      _ -> nil
    end

    assert_no_email_sent()
  end

  test "assert no email sent with email sent" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_no_email_sent()
    end
  end

  test "assert no email sent when sending an email", %{email: email} do
    message =
      "Unexpectedly received message {:email, #{inspect(email)} (which matched {:email, _})"

    try do
      assert_no_email_sent()
    rescue
      error in [ExUnit.AssertionError] ->
        assert message, error.message
    end
  end

  test "refute email sent" do
    receive do
      _ -> nil
    end

    refute_email_sent()
  end

  test "refute email sent with email sent" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent()
    end
  end

  test "refute email sent with unexpected email" do
    unexpected_email = new() |> subject("Testing Avenger")
    refute_email_sent(^unexpected_email)
  end

  test "refute email sent with expected email", %{email: email} do
    message =
      "Unexpectedly received message {:email, #{inspect(email)}} (which matched {:email, ^email})"

    try do
      refute_email_sent(^email)
    rescue
      error in [ExUnit.AssertionError] ->
        assert message, error.message
    end
  end

  test "refute email sent with specific params" do
    refute_email_sent(
      subject: "Good bye, Avengers!",
      to: "steve.rogers@example.com"
    )
  end

  test "refute email sent with expected params" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(
        subject: "Hello, Avengers!",
        to: ["steve.rogers@example.com", "bruce.banner@example.com"]
      )
    end
  end

  test "refute email sent with specific from" do
    refute_email_sent(from: "steve.rogers@example.com")
  end

  test "refute email sent with expected from" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(from: "tony.stark@example.com")
    end
  end

  test "refute email sent with specific reply to" do
    refute_email_sent(reply_to: "steve.rogers@example.com")
  end

  test "refute email sent with expected reply to" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(reply_to: "bruce.banner@example.com")
    end
  end

  test "refute email sent with specific to" do
    refute_email_sent(to: "steve.rogers@example.com")
  end

  test "refute email sent with specific to (list)" do
    refute_email_sent(to: ["steve.rogers@example.com"])
  end

  test "refute email sent with expected to" do
    assert_email_sent(
      to: ["steve.rogers@example.com", "bruce.banner@example.com"]
    )

    deliver(new(to: "steve.rogers@example.com"))

    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(to: "steve.rogers@example.com")
    end
  end

  test "refute email sent with expected to (list)" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(
        to: ["steve.rogers@example.com", "bruce.banner@example.com"]
      )
    end
  end

  test "refute email sent with specific cc" do
    refute_email_sent(cc: "natasha.romanoff@example.com")
  end

  test "refute email sent with specific cc (list)" do
    refute_email_sent(cc: ["natasha.romanoff@example.com"])
  end

  test "refute email sent with expected cc" do
    assert_email_sent(
      cc: ["natasha.romanoff@example.com", "stephen.strange@example.com"]
    )

    deliver(new(cc: "natasha.romanoff@example.com"))

    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(cc: "natasha.romanoff@example.com")
    end
  end

  test "refute email sent with expected cc (list)" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(
        cc: ["natasha.romanoff@example.com", "stephen.strange@example.com"]
      )
    end
  end

  test "refute email sent with specific bcc" do
    refute_email_sent(bcc: "steve.rogers@example.com")
  end

  test "refute email sent with specific bcc (list)" do
    refute_email_sent(bcc: ["steve.rogers@example.com"])
  end

  test "refute email sent with expected bcc" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(bcc: "loki.odinson@example.com")
    end
  end

  test "refute email sent with expected bcc (list)" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(bcc: ["loki.odinson@example.com"])
    end
  end

  test "refute email sent with specific subject" do
    refute_email_sent(subject: "Hello, League!")
  end

  test "refute email sent with expected subject" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(subject: "Hello, Avengers!")
    end
  end

  test "refute email sent with specific text body" do
    refute_email_sent(text_body: "some html")
  end

  test "refute email sent with expected text body" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(text_body: "some text")
    end
  end

  test "refute email sent with specific html body" do
    refute_email_sent(html_body: "some text")
  end

  test "refute email sent with expected html body" do
    assert_raise ExUnit.AssertionError, fn ->
      refute_email_sent(html_body: "some html")
    end
  end
end
