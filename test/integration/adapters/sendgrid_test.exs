defmodule Swoosh.Integration.Adapters.SendgridTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [api_key: System.get_env("SENDGRID_API_KEY"), domain: Sytem.get_env("SENDGRID_DOMAIN")]
    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new
      |> from({"Swoosh Sendgrid", "swoosh+sendgrid#{config[:domain]}"})
      |> reply_to("swoosh+replyto#{config[:domain]}")
      |> to("swoosh+to#{config[:domain]}")
      |> cc("swoosh+cc#{config[:domain]}")
      |> bcc("swoosh+bcc#{config[:domain]}")
      |> subject("Swoosh - Sendgrid integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.Sendgrid.deliver(email, config)
  end
end
