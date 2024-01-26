defmodule Swoosh.Integration.Adapters.MailtrapTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [
      api_key: System.get_env("MAILTRAP_API_KEY"),
      domain: System.get_env("MAILTRAP_DOMAIN"),
      destination_domain: System.get_env("MAILTRAP_DEST_DOMAIN")
    ]

    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new()
      |> from({"Swoosh Mailtrap", "swoosh+mailtrap@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@#{config[:destination_domain]}")
      |> cc("swoosh+cc@#{config[:destination_domain]}")
      |> bcc("swoosh+bcc@#{config[:destination_domain]}")
      |> subject("Swoosh - Mailtrap integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.Mailtrap.deliver(email, config)
  end

  test "sandbox deliver", %{config: config} do
    email =
      new()
      |> from({"Swoosh Mailtrap", "swoosh+mailtrap@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@#{config[:destination_domain]}")
      |> cc("swoosh+cc@#{config[:destination_domain]}")
      |> bcc("swoosh+bcc@#{config[:destination_domain]}")
      |> subject("Swoosh - Mailtrap integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    sandbox_config = [sandbox_inbox_id: System.get_env("MAILTRAP_INBOX")]

    assert {:ok, _response} = Swoosh.Adapters.Mailtrap.deliver(email, config ++ sandbox_config)
  end
end
