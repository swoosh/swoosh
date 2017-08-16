defmodule Swoosh.Email.SMTPTest do
  use ExUnit.Case, async: true

  alias Swoosh.Adapters.SMTP.Helpers

  import Swoosh.Email

  setup_all do
    valid_email =
      new()
      |> from("tony@stark.com")
      |> to("steve@rogers.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    valid_config = [
      dkim: [
        s: "default",
        d: "example.com",
        private_key: {
          :pem_plain,
          "-----BEGIN RSA PRIVATE KEY-----
          #{String.duplicate("abcdefghijklmnopqrstuvwxyz\n", 13)}
          -----END RSA PRIVATE KEY-----\n"
        }
      ]
    ]

    {:ok, valid_email: valid_email, valid_config: valid_config}
  end

  test "simple email", %{valid_email: email} do
    email = email |> html_body(nil)
    assert Helpers.prepare_message(email) ==
     {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony@stark.com"},
        {"To", "steve@rogers.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "Hello"}
  end

  test "simple email with all basic fields", %{valid_email: email} do
    email =
      email
      |> html_body(nil)
      |> to({"Janet Pym", "wasp@avengers.com"})
      |> cc({"Bruce Banner", "hulk@smash.com"})
      |> cc("thor@odinson.com")
      |> bcc({"Clinton Francis Barton", "hawk@eye.com"})
      |> bcc("beast@avengers.com")
      |> reply_to("black@widow.com")
      |> header("X-Custom-ID", "4f034001")
      |> header("X-Feedback-ID", "403f4983b02a")

    assert Helpers.prepare_message(email) ==
    {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony@stark.com"},
        {"To", "\"Janet Pym\" <wasp@avengers.com>, steve@rogers.com"},
        {"Cc", "thor@odinson.com, \"Bruce Banner\" <hulk@smash.com>"},
        {"Bcc", "beast@avengers.com, \"Clinton Francis Barton\" <hawk@eye.com>"},
        {"Subject", "Hello, Avengers!"},
        {"Reply-To", "black@widow.com"},
        {"Mime-Version", "1.0"},
        {"X-Custom-ID", "4f034001"},
        {"X-Feedback-ID", "403f4983b02a"}],
      "Hello"}
  end

  test "simple email with multiple recipients", %{valid_email: email} do
    email = email |> html_body(nil) |> to({"Bruce Banner", "bruce@banner.com"})
    assert Helpers.prepare_message(email) ==
    {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony@stark.com"},
        {"To", "\"Bruce Banner\" <bruce@banner.com>, steve@rogers.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "Hello"}
  end

  test "simple email with multiple cc recipients", %{valid_email: email} do
    email =
    email
    |> html_body(nil)
    |> to({"Bruce Banner", "bruce@banner.com"})
    |> cc("thor@odinson.com")

    assert Helpers.prepare_message(email) ==
      {"text", "plain",
       [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony@stark.com"},
        {"To", "\"Bruce Banner\" <bruce@banner.com>, steve@rogers.com"},
        {"Cc", "thor@odinson.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
       "Hello"}
  end

  test "simple html email", %{valid_email: email} do
    email = email |> text_body(nil)
    assert Helpers.prepare_message(email) ==
      {"text", "html",
       [{"Content-Type", "text/html; charset=\"utf-8\""},
        {"From", "tony@stark.com"},
        {"To", "steve@rogers.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "<h1>Hello</h1>"}
  end

  test "multipart/alternative email", %{valid_email: email} do
    assert Helpers.prepare_message(email) ==
      {"multipart", "alternative",
       [{"From", "tony@stark.com"},
        {"To", "steve@rogers.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
       [{"text", "plain",
         [{"Content-Type", "text/plain; charset=\"utf-8\""},
          {"Content-Transfer-Encoding", "quoted-printable"}],
         [{"content-type-params", [{"charset", "utf-8"}]},
          {"disposition", "inline"},
          {"disposition-params", []}],
         "Hello"},
        {"text", "html",
         [{"Content-Type", "text/html; charset=\"utf-8\""},
          {"Content-Transfer-Encoding", "quoted-printable"}],
         [{"content-type-params", [{"charset", "utf-8"}]},
          {"disposition", "inline"},
          {"disposition-params", []}],
        "<h1>Hello</h1>"}]}
  end

  test "no dkim in config", %{} do
    assert Helpers.prepare_options([]) == []
  end

  test "dkim in config", %{valid_config: config} do
    assert Helpers.prepare_options(config) == [{:dkim, config[:dkim]}]
  end
end
