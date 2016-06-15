defmodule Swoosh.Integration.Adapters.SMTPTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [
      relay: System.get_env("SMTP_RELAY"),
      username: System.get_env("SMTP_USERNAME"),
      password: System.get_env("SMTP_PASSWORD"),
      tls: :always,
      auth: :always
    ]
    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new
      |> from({"Swoosh SMTP", "swoosh+smtp@elixirhq.com"})
      |> reply_to("swoosh+replyto@elixirhq.com")
      |> to("swoosh+to@elixirhq.com")
      |> cc("swoosh+cc@elixirhq.com")
      |> bcc("swoosh+bcc@elixirhq.com")
      |> subject("Swoosh - SMTP integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.SMTP.deliver(email, config)
  end
end
