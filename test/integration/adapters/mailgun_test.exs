defmodule Swoosh.Integration.Adapters.MailgunTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [domain: System.get_env("MAILGUN_DOMAIN"),
	      api_key: System.get_env("MAILGUN_API_KEY")]
    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new
      |> from({"Swoosh Mailgun", "swoosh@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@elixirhq.com")
      |> cc("swoosh+cc@elixirhq.com")
      |> bcc("swoosh+bcc@elixirhq.com")
      |> subject("Swoosh - Mailgun integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.Mailgun.deliver(email, config)
  end

  test ":error with wrong api key", %{config: config} do
    config = Keyword.put(config, :api_key, "bad_key")

    email =
      new
      |> from({"Swoosh Mailgun", "swoosh@#{config[:domain]}"})
      |> to("swoosh+to@elixirhq.com")
      |> subject("Swoosh - Mailgun integration test")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:error, "Forbidden"} = Swoosh.Adapters.Mailgun.deliver(email, config)
  end
end
