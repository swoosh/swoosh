defmodule Swoosh.Integration.Adapters.PostalTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [
      base_url: System.get_env("POSTAL_BASE_URL"),
      api_key: System.get_env("POSTAL_API_KEY"),
      domain: System.get_env("POSTAL_DOMAIN")
    ]

    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new()
      |> from({"Swoosh Postal", "swoosh+postal@#{config[:domain]}"})
      |> reply_to("swoosh+replyto@#{config[:domain]}")
      |> to("swoosh+to@#{config[:domain]}")
      |> cc("swoosh+cc@#{config[:domain]}")
      |> bcc("swoosh+bcc@#{config[:domain]}")
      |> subject("Swoosh - Postal integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")
      |> put_provider_option(:tag, "swoosh-integration-test")
      |> attachment(%Swoosh.Attachment{
        content_type: "text/plain",
        data: "this is an attachment",
        filename: "example.txt",
        type: :attachment,
        headers: []
      })

    assert {:ok, _response} = Swoosh.Adapters.Postal.deliver(email, config)
  end

  test ":error with wrong api key", %{config: config} do
    config = Keyword.put(config, :api_key, "bad_key")

    email =
      new()
      |> from({"Swoosh Postal", "swoosh+postal@#{config[:domain]}"})
      |> to("swoosh+to@#{config[:domain]}")
      |> subject("Swoosh - Postal integration test")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:error, {"InvalidServerAPIKey", _}} = Swoosh.Adapters.Postal.deliver(email, config)
  end
end
