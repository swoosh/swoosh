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
    Swoosh.Adapters.Test.deliver(email, nil)
    {:ok, email: email}
  end

  test "assert email sent with correct email", %{email: email} do
    assert_email_sent email
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

  test "assert email sent with wrong email" do
    try do
      wrong_email = new() |> subject("Wrong, Avengers!")
      assert_email_sent wrong_email
    rescue
      error in [ExUnit.AssertionError] ->
        "No message matching {:email, ^email} after 0ms.\n" <>
        "The following variables were pinned:\n" <>
        "  email = %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Wrong, Avengers!\", text_body: nil, to: []}\n" <>
        "Process mailbox:\n" <>
        "  {:email, %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: {\"\", \"tony.stark@example.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve.rogers@example.com\"}]}}"
        = error.message
    end
  end

  test "assert email not sent with unexpected email" do
    unexpected_email = new() |> subject("Testing Avenger")
    assert_email_not_sent unexpected_email
  end

  test "assert email not sent with expected email", %{email: email} do
    try do
      assert_email_not_sent email
    rescue
      error in [ExUnit.AssertionError] ->
        "Unexpectedly received message {:email, %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: {\"\", \"tony.stark@example.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve.rogers@example.com\"}]}} " <>
        "(which matched {:email, ^email})" = error.message
    end
  end

  test "assert no email sent" do
    receive do
      _ -> nil
    end
    assert_no_email_sent()
  end

  test "assert no email sent when sending an email" do
    try do
      assert_no_email_sent()
    rescue
      error in [ExUnit.AssertionError] ->
        "Unexpectedly received message {:email, %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: {\"\", \"tony.stark@example.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve.rogers@example.com\"}]}} " <>
        "(which matched {:email, _})" = error.message
    end
  end
end
