defmodule Swoosh.Adapters.SMTPTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.SMTP

  setup_all do
    valid_email =
      new
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    valid_config = [
      relay: "localhost",
      dkim: [s: "default", d: "example.com",
      private_key: {:pem_plain,                                                                                                                                                                                                                 "-----BEGIN RSA PRIVATE KEY-----
      #{String.duplicate("abcdefghijklmnopqrstuvwxyz\n", 13)}
      -----END RSA PRIVATE KEY-----\n"}]
    ]

    {:ok, valid_email: valid_email, valid_config: valid_config}
  end

  test "simple email", %{valid_email: email} do
    email = email |> html_body(nil)
    assert SMTP.prepare_message(email) ==
     {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony.stark@example.com"},
        {"To", "steve.rogers@example.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "Hello"}
  end

  test "simple email with all basic fields", %{valid_email: email} do
    email =
      email
      |> html_body(nil)
      |> to({"Janet Pym", "wasp.avengers@example.com"})
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> reply_to("black.widow@example.com")
      |> header("X-Custom-ID", "4f034001")
      |> header("X-Feedback-ID", "403f4983b02a")

    assert SMTP.prepare_message(email) ==
    {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony.stark@example.com"},
        {"To", "Janet Pym <wasp.avengers@example.com>, steve.rogers@example.com"},
        {"Cc", "thor.odinson@example.com, Bruce Banner <hulk.smash@example.com>"},
        {"Subject", "Hello, Avengers!"},
        {"Reply-To", "black.widow@example.com"},
        {"Mime-Version", "1.0"},
        {"X-Custom-ID", "4f034001"},
        {"X-Feedback-ID", "403f4983b02a"}],
      "Hello"}
  end

  test "simple email with multiple recipients", %{valid_email: email} do
    email = email |> html_body(nil) |> to({"Bruce Banner", "bruce.banner@example.com"})
    assert SMTP.prepare_message(email) ==
    {"text", "plain",
      [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony.stark@example.com"},
        {"To", "Bruce Banner <bruce.banner@example.com>, steve.rogers@example.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "Hello"}
  end

  test "simple email with multiple cc recipients", %{valid_email: email} do
    email =
    email
    |> html_body(nil)
    |> to({"Bruce Banner", "bruce.banner@example.com"})
    |> cc("thor.odinson@example.com")

    assert SMTP.prepare_message(email) ==
      {"text", "plain",
       [{"Content-Type", "text/plain; charset=\"utf-8\""},
        {"From", "tony.stark@example.com"},
        {"To", "Bruce Banner <bruce.banner@example.com>, steve.rogers@example.com"},
        {"Cc", "thor.odinson@example.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
       "Hello"}
  end

  test "simple html email", %{valid_email: email} do
    email = email |> text_body(nil)
    assert SMTP.prepare_message(email) ==
      {"text", "html",
       [{"Content-Type", "text/html; charset=\"utf-8\""},
        {"From", "tony.stark@example.com"},
        {"To", "steve.rogers@example.com"},
        {"Subject", "Hello, Avengers!"},
        {"Mime-Version", "1.0"}],
      "<h1>Hello</h1>"}
  end

  test "multipart/alternative email", %{valid_email: email} do
    assert SMTP.prepare_message(email) ==
      {"multipart", "alternative",
       [{"From", "tony.stark@example.com"},
        {"To", "steve.rogers@example.com"},
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
    assert SMTP.prepare_options([]) == []
  end

  test "dkim in config", %{valid_config: config} do
    assert SMTP.prepare_options(config) == [{:dkim, config[:dkim]}]
  end

  test "validate_config/1 with valid config", %{valid_config: config} do
    assert SMTP.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:relay] to be set, got: []
    """, fn ->
      SMTP.validate_config([])
    end
  end
end
