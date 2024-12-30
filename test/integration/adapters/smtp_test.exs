defmodule Swoosh.Integration.Adapters.SMTPTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  defp config(Swoosh.Adapters.SMTP) do
    [
      relay: System.get_env("SMTP_RELAY"),
      username: System.get_env("SMTP_USERNAME"),
      password: System.get_env("SMTP_PASSWORD"),
      domain: System.get_env("SMTP_DOMAIN"),
      tls: :always,
      auth: :always
    ]
  end

  defp config(Swoosh.Adapters.Mua) do
    relay = System.get_env("SMTP_RELAY", "localhost")
    domain = System.get_env("SMTP_DOMAIN", "mua.local")
    port = String.to_integer(System.get_env("SMTP_PORT", "1025"))

    username = System.get_env("SMTP_USERNAME")
    password = System.get_env("SMTP_PASSWORD")
    auth = if username && password, do: [username: username, password: password]

    [relay: relay, port: port, domain: domain, auth: auth]
  end

  for adapter <- [Swoosh.Adapters.SMTP, Swoosh.Adapters.Mua] do
    describe "using #{adapter}" do
      setup do
        {:ok, config: config(unquote(adapter))}
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

        assert {:ok, _response} = unquote(adapter).deliver(email, config)
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

        assert {:ok, _response} = unquote(adapter).deliver(email, config)
      end
    end
  end
end
