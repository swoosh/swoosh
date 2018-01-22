defmodule Swoosh.Integration.Adapters.SMTPTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [
      relay: System.get_env("SMTP_RELAY"),
      username: System.get_env("SMTP_USERNAME"),
      password: System.get_env("SMTP_PASSWORD"),
      domain: System.get_env("SMTP_DOMAIN"),
      tls: :always,
      auth: :always
    ]
    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new()
      |> from({"Swoosh SMTP", "swoosh+smtp@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@#{config[:domain]}")
      |> cc("swoosh+cc@#{config[:domain]}")
      |> bcc("swoosh+bcc@#{config[:domain]}")
      |> subject("Swoosh - SMTP integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.SMTP.deliver(email, config)
  end

  test "deliver with attachment in memory", %{config: config} do
    email =
      new()
      |> from({"Swoosh SMTP", "swoosh+smtp@#{config[:domain]}"})
      |> to("swoosh+to@#{config[:domain]}")
      |> subject("Swoosh - SMTP integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> attachment(%Swoosh.Attachment{
        content_type: "text/plain",
        data: "this is an attachment",
        filename: "example.txt",
        type: :attachment,
        headers: []
      })
    assert {:ok, _response} = Swoosh.Adapters.SMTP.deliver(email, config)
  end

end
