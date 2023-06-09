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

    {:ok, valid_email: valid_email}
  end

  test "simple email", %{valid_email: email} do
    email = email |> html_body(nil)

    assert Helpers.prepare_message(email, []) ==
             {"text", "plain",
              [
                {"Content-Type", "text/plain; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"To", "steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ], "Hello"}
  end

  test "simple email without to", %{valid_email: email} do
    email = email |> html_body(nil) |> put_to(nil)

    assert Helpers.prepare_message(email, []) ==
             {"text", "plain",
              [
                {"Content-Type", "text/plain; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ], "Hello"}
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

    assert Helpers.prepare_message(email, []) ==
             {"text", "plain",
              [
                {"Content-Type", "text/plain; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"To", "\"Janet Pym\" <wasp@avengers.com>, steve@rogers.com"},
                {"Cc", "thor@odinson.com, \"Bruce Banner\" <hulk@smash.com>"},
                {"Subject", "Hello, Avengers!"},
                {"Reply-To", "black@widow.com"},
                {"MIME-Version", "1.0"},
                {"X-Custom-ID", "4f034001"},
                {"X-Feedback-ID", "403f4983b02a"}
              ], "Hello"}
  end

  test "simple email with multiple recipients", %{valid_email: email} do
    email = email |> html_body(nil) |> to({"Bruce Banner", "bruce@banner.com"})

    assert Helpers.prepare_message(email, []) ==
             {"text", "plain",
              [
                {"Content-Type", "text/plain; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"To", "\"Bruce Banner\" <bruce@banner.com>, steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ], "Hello"}
  end

  test "simple email with multiple cc recipients", %{valid_email: email} do
    email =
      email
      |> html_body(nil)
      |> to({"Bruce Banner", "bruce@banner.com"})
      |> cc("thor@odinson.com")

    assert Helpers.prepare_message(email, []) ==
             {"text", "plain",
              [
                {"Content-Type", "text/plain; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"To", "\"Bruce Banner\" <bruce@banner.com>, steve@rogers.com"},
                {"Cc", "thor@odinson.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ], "Hello"}
  end

  test "simple html email", %{valid_email: email} do
    email = email |> text_body(nil)

    assert Helpers.prepare_message(email, []) ==
             {"text", "html",
              [
                {"Content-Type", "text/html; charset=\"utf-8\""},
                {"From", "tony@stark.com"},
                {"To", "steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ], "<h1>Hello</h1>"}
  end

  test "multipart/alternative email", %{valid_email: email} do
    assert Helpers.prepare_message(email, []) ==
             {"multipart", "alternative",
              [
                {"From", "tony@stark.com"},
                {"To", "steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ],
              [
                {"text", "plain",
                 [
                   {"Content-Type", "text/plain; charset=\"utf-8\""},
                   {"Content-Transfer-Encoding", "quoted-printable"}
                 ],
                 %{
                   content_type_params: [{"charset", "utf-8"}],
                   disposition: "inline",
                   disposition_params: []
                 }, "Hello"},
                {"text", "html",
                 [
                   {"Content-Type", "text/html; charset=\"utf-8\""},
                   {"Content-Transfer-Encoding", "quoted-printable"}
                 ],
                 %{
                   content_type_params: [{"charset", "utf-8"}],
                   disposition: "inline",
                   disposition_params: []
                 }, "<h1>Hello</h1>"}
              ]}
  end

  test "multipart/mixed email", %{valid_email: email} do
    email =
      email
      |> attachment(%Swoosh.Attachment{
        content_type: "text/plain",
        data: "this is an attachment",
        filename: "example.txt",
        type: :attachment,
        headers: []
      })

    assert Helpers.prepare_message(email, []) ==
             {"multipart", "mixed",
              [
                {"From", "tony@stark.com"},
                {"To", "steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ],
              [
                {"multipart", "alternative", [], %{},
                 [
                   {"text", "plain",
                    [
                      {"Content-Type", "text/plain; charset=\"utf-8\""},
                      {"Content-Transfer-Encoding", "quoted-printable"}
                    ],
                    %{
                      content_type_params: [{"charset", "utf-8"}],
                      disposition: "inline",
                      disposition_params: []
                    }, "Hello"},
                   {"text", "html",
                    [
                      {"Content-Type", "text/html; charset=\"utf-8\""},
                      {"Content-Transfer-Encoding", "quoted-printable"}
                    ],
                    %{
                      content_type_params: [{"charset", "utf-8"}],
                      disposition: "inline",
                      disposition_params: []
                    }, "<h1>Hello</h1>"}
                 ]},
                {"text", "plain", [{"Content-Transfer-Encoding", "base64"}],
                 %{disposition: "attachment", disposition_params: [{"filename", "example.txt"}]},
                 "this is an attachment"}
              ]}
  end

  test "multipart/mixed/related email", %{valid_email: email} do
    email =
      email
      |> attachment(%Swoosh.Attachment{
        content_type: "text/plain",
        data: "this is an attachment",
        filename: "example.txt",
        type: :inline,
        headers: []
      })

    assert Helpers.prepare_message(email, []) ==
             {"multipart", "mixed",
              [
                {"From", "tony@stark.com"},
                {"To", "steve@rogers.com"},
                {"Subject", "Hello, Avengers!"},
                {"MIME-Version", "1.0"}
              ],
              [
                {"multipart", "alternative", [], %{},
                 [
                   {"text", "plain",
                    [
                      {"Content-Type", "text/plain; charset=\"utf-8\""},
                      {"Content-Transfer-Encoding", "quoted-printable"}
                    ],
                    %{
                      content_type_params: [{"charset", "utf-8"}],
                      disposition: "inline",
                      disposition_params: []
                    }, "Hello"},
                   {"multipart", "related", [], %{},
                    [
                      {"text", "html",
                       [
                         {"Content-Type", "text/html; charset=\"utf-8\""},
                         {"Content-Transfer-Encoding", "quoted-printable"}
                       ],
                       %{
                         content_type_params: [{"charset", "utf-8"}],
                         disposition: "inline",
                         disposition_params: []
                       }, "<h1>Hello</h1>"},
                      {"text", "plain",
                       [{"Content-Transfer-Encoding", "base64"}, {"Content-Id", "<example.txt>"}],
                       %{
                         disposition: "inline",
                         disposition_params: [{"filename", "example.txt"}],
                         content_type_params: []
                       }, "this is an attachment"}
                    ]}
                 ]}
              ]}
  end

  test "message includes to and cc, but omits the bcc header according to RFC 5322" do
    email =
      new()
      |> from("from@test.com")
      |> to("to@test.com")
      |> cc("cc@test.com")
      |> bcc("bcc@test.com")

    {_type, _subtype, headers, _parts} = Helpers.prepare_message(email, %{})

    assert {"To", "to@test.com"} in headers
    assert {"Cc", "cc@test.com"} in headers
    refute {"Bcc", "bcc@test.com"} in headers
  end
end
