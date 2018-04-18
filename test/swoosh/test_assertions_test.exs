defmodule Swoosh.TestAssertionsTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  setup do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("some html")
      |> text_body("some text")

    Swoosh.Adapters.Test.deliver(email, nil)
    {:ok, email: email}
  end

  test "assert email sent with correct email", %{email: email} do
    assert_email_sent email
  end

  test "assert email sent with some content matched by a regex" do
    assert_email_sent text_body: ~r/some text/, html_body: ~r/html$/
  end

  test "assert email sent with specific params" do
    assert_email_sent [subject: "Hello, Avengers!", to: "steve.rogers@example.com"]
  end

  test "assert email sent with specific to (list)" do
    assert_email_sent [to: ["steve.rogers@example.com"]]
  end

  test "assert email sent with wrong subject" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [subject: "Hello, X-Men!"]
    end
  end

  test "assert email sent with wrong from" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [from: "thor.odinson@example.com"]
    end
  end

  test "assert email sent with wrong to" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [to: "bruce.banner@example.com"]
    end
  end

  test "assert email sent with wrong to (list)" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [to: ["bruce.banner@example.com"]]
    end
  end

  test "assert email sent with wrong cc" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [cc: "bruce.banner@example.com"]
    end
  end

  test "assert email sent with wrong bcc" do
    assert_raise ExUnit.AssertionError, fn ->
      assert_email_sent [bcc: "bruce.banner@example.com"]
    end
  end

  test "assert email sent with wrong email", %{email: email} do
    wrong_email = new() |> subject("Wrong, Avengers!")

    message =
      String.trim(
        """
        No message matching {:email, ^email} after 0ms.
        The following variables were pinned:
          email = #{inspect(wrong_email)}
        Process mailbox:
          {:email, #{inspect(email)}}
        """
      )

    try do
      assert_email_sent wrong_email
    rescue
      error in [ExUnit.AssertionError] ->
        assert message == error.message
    end
  end

  test "assert email not sent with unexpected email" do
    unexpected_email = new() |> subject("Testing Avenger")
    assert_email_not_sent unexpected_email
  end

  test "assert email not sent with expected email", %{email: email} do
    message = "Unexpectedly received message {:email, #{inspect(email)}} (which matched {:email, ^email})"

    try do
      assert_email_not_sent email
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

  test "assert no email sent when sending an email", %{email: email} do
    message = "Unexpectedly received message {:email, #{inspect(email)} (which matched {:email, _})"

    try do
      assert_no_email_sent()
    rescue
      error in [ExUnit.AssertionError] ->
        assert message, error.message
    end
  end
end
