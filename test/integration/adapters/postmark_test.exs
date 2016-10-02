defmodule Swoosh.Integration.Adapters.PostmarkTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  @config [
    api_key: System.get_env("POSTMARK_API_KEY"),
    domain:  System.get_env("POSTMARK_DOMAIN"),
  ]

  @base_email new
              |> from({"Swoosh Postmark", "swoosh@#{@config[:domain]}"})
              |> reply_to("swoosh+replyto@#{@config[:domain]}")
              |> to("swoosh+to@#{@config[:domain]}")
              |> cc("swoosh+cc@#{@config[:domain]}")
              |> bcc("swoosh+bcc@#{@config[:domain]}")

  test "simple deliver" do
    email =
      @base_email
      |> subject("Swoosh - Postmark integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert_ok_response(email)
  end

  test "template deliver" do
    config         = Keyword.put_new(@config, :template, true)
    template_model = %{
      name:    "Swoosh",
      action_url: "Postmark",
    }
    email =
      @base_email
      |> put_provider_option(:template_id,    968101)
      |> put_provider_option(:template_model, template_model)

    assert_ok_response(email, config)
  end

  defp assert_ok_response(email, config \\ @config),
    do: assert {:ok, _response} = Swoosh.Adapters.Postmark.deliver(email, config)
end
