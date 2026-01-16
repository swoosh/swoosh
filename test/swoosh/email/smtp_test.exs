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

  test "simple email with quotes and backslashes in the recipient names", %{valid_email: email} do
    email =
      email
      |> html_body(nil)
      |> from({~s|Tony "Iron Man" Stark|, "tony@stark.com"})
      |> to({~s|Steve "Cap" Rogers|, "steve@rogers.com"})
      |> cc({~s|\\Loki\\|, "loki@jotunheim.god"})

    assert Helpers.prepare_message(email, []) ==
             {
               "text",
               "plain",
               [
                 {"Content-Type", "text/plain; charset=\"utf-8\""},
                 {"From", ~s|"Tony \\"Iron Man\\" Stark" <tony@stark.com>|},
                 {"To", ~s|"Steve \\"Cap\\" Rogers" <steve@rogers.com>, steve@rogers.com|},
                 {"Cc", ~s|"\\\\Loki\\\\" <loki@jotunheim.god>|},
                 {"Subject", "Hello, Avengers!"},
                 {"MIME-Version", "1.0"}
               ],
               "Hello"
             }
  end

  test "simple email to recipients with non-ASCII characters domains", %{valid_email: email} do
    email =
      email
      |> html_body(nil)
      |> from({nil, "tony@stärk.com"})
      |> cc({"", "loki@jötunheim.god"})
      |> to({"Steve Rogers", "steve@rœgers.com"})

    assert Helpers.prepare_message(email, []) ==
             {
               "text",
               "plain",
               [
                 {"Content-Type", "text/plain; charset=\"utf-8\""},
                 {"From", "tony@xn--strk-moa.com"},
                 {"To", "\"Steve Rogers\" <steve@xn--rgers-hbb.com>, steve@rogers.com"},
                 {"Cc", "loki@xn--jtunheim-n4a.god"},
                 {"Subject", "Hello, Avengers!"},
                 {"MIME-Version", "1.0"}
               ],
               "Hello"
             }
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

  test "message/rfc822 attachment uses 8bit encoding per RFC 2046", %{valid_email: email} do
    rfc822_content = """
    From: original@sender.com
    To: original@recipient.com
    Subject: Forwarded message

    This is the original message body.
    """

    email =
      email
      |> attachment(%Swoosh.Attachment{
        content_type: "message/rfc822",
        data: rfc822_content,
        filename: "forwarded.eml",
        type: :attachment,
        headers: []
      })

    {"multipart", "mixed", _headers, [_content_part, attachment_part]} =
      Helpers.prepare_message(email, [])

    {"message", "rfc822", attachment_headers, _params, _content} = attachment_part

    assert {"Content-Transfer-Encoding", "8bit"} in attachment_headers
  end

  test "message/partial attachment uses 7bit encoding per RFC 2046", %{valid_email: email} do
    email =
      email
      |> attachment(%Swoosh.Attachment{
        content_type: "message/partial",
        data: "partial message content",
        filename: "partial.eml",
        type: :attachment,
        headers: []
      })

    {"multipart", "mixed", _headers, [_content_part, attachment_part]} =
      Helpers.prepare_message(email, [])

    {"message", "partial", attachment_headers, _params, _content} = attachment_part

    assert {"Content-Transfer-Encoding", "7bit"} in attachment_headers
  end
end
