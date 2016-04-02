defmodule Swoosh.TestAssertionsTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  setup do
    email =
      new
      |> from("tony@stark.com")
      |> to("steve@rogers.com")
      |> subject("Hello, Avengers!")
    Swoosh.Adapters.Test.deliver(email, nil)
    {:ok, email: email}
  end

  test "assert email sent with correct email", %{email: email} do
    assert_email_sent email
  end

  test "assert email sent with wrong email" do
    try do
      wrong_email = new |> subject("Wrong, Avengers!")
      assert_email_sent wrong_email
    rescue
      error in [ExUnit.AssertionError] ->
        "No message matching {:email, ^email} after 0ms.\n" <>
        "The following variables were pinned:\n" <>
        "  email = %Swoosh.Email{assigns: %{}, attachments: nil, bcc: [], cc: [], from: nil, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Wrong, Avengers!\", text_body: nil, to: []}\n" <>
        "Process mailbox:\n" <>
        "  {:email, %Swoosh.Email{assigns: %{}, attachments: nil, bcc: [], cc: [], from: {\"\", \"tony@stark.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve@rogers.com\"}]}}"
        = error.message
    end
  end

  test "assert email not sent with unexpected email" do
    unexpected_email = new |> subject("Testing Avenger")
    assert_email_not_sent unexpected_email
  end

  test "assert email not sent with expected email", %{email: email} do
    try do
      assert_email_not_sent email
    rescue
      error in [ExUnit.AssertionError] ->
        "Unexpectedly received message {:email, %Swoosh.Email{assigns: %{}, attachments: nil, bcc: [], cc: [], from: {\"\", \"tony@stark.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve@rogers.com\"}]}} " <>
        "(which matched {:email, ^email})" = error.message
    end
  end

  test "assert no email sent" do
    receive do
      _ -> nil
    end
    assert_no_email_sent
  end

  test "assert no email sent when sending an email" do
    try do
      assert_no_email_sent
    rescue
      error in [ExUnit.AssertionError] ->
        "Unexpectedly received message {:email, %Swoosh.Email{assigns: %{}, attachments: nil, bcc: [], cc: [], from: {\"\", \"tony@stark.com\"}, headers: %{}, html_body: nil, private: %{}, provider_options: %{}, reply_to: nil, subject: \"Hello, Avengers!\", text_body: nil, to: [{\"\", \"steve@rogers.com\"}]}} " <>
        "(which matched {:email, _})" = error.message
    end
  end
end
