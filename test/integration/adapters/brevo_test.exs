defmodule Swoosh.Integration.Adapters.BrevoTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [
      api_key: System.get_env("BREVO_API_KEY") || System.get_env("SENDINBLUE_API_KEY"),
      domain: System.get_env("BREVO_DOMAIN") || System.get_env("SENDINBLUE_DOMAIN")
    ]

    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new()
      |> from({"Swoosh Brevo", "swoosh+brevo@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@#{config[:domain]}")
      |> cc("swoosh+cc@#{config[:domain]}")
      |> bcc("swoosh+bcc@#{config[:domain]}")
      |> subject("Swoosh - Brevo integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, %{id: _}} = Swoosh.Adapters.Brevo.deliver(email, config)
  end
end
