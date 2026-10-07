defmodule Swoosh.Adapters.MailChannels.MessageTest do
  use ExUnit.Case, async: true
  import Swoosh.Email
  alias Swoosh.Adapters.MailChannels.Message

  defp mail do
    new()
    |> from({"Équipe", "sender@example.test"})
    |> to({"Zoë", "to@example.test"})
    |> subject("Résumé 東京")
    |> text_body("Hello\n東京")
  end

  test "preserves recipient roles, raw Unicode and text/html alternatives" do
    email =
      mail()
      |> cc("copy@example.test")
      |> bcc("hidden@example.test")
      |> reply_to("reply@example.test")
      |> html_body("<p>東京</p>")
      |> header("X-Audit", "test")

    assert {:ok, body} = Message.prepare(email)
    assert body.from == %{name: "Équipe", email: "sender@example.test"}

    assert body.personalizations == [
             %{
               to: [%{name: "Zoë", email: "to@example.test"}],
               cc: [%{email: "copy@example.test"}],
               bcc: [%{email: "hidden@example.test"}]
             }
           ]

    assert body.subject == "Résumé 東京"
    assert body.reply_to == %{email: "reply@example.test"}

    assert body.content == [
             %{type: "text/plain", value: "Hello\n東京"},
             %{type: "text/html", value: "<p>東京</p>"}
           ]

    assert body.headers == %{"X-Audit" => "test"}
    assert not Map.has_key?(body, :attachments)
  end

  test "file, binary and inline attachments are encoded once" do
    path = Path.join(System.tmp_dir!(), "mc-#{System.unique_integer([:positive])}.txt")
    File.write!(path, "local content")
    on_exit(fn -> File.rm(path) end)

    email =
      mail()
      |> attachment(
        Swoosh.Attachment.new({:data, <<0, 255, 13, 10>>},
          filename: "résumé.pdf",
          content_type: "application/pdf"
        )
      )
      |> attachment(
        Swoosh.Attachment.new({:data, "png"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo@fixture"
        )
      )
      |> attachment(Swoosh.Attachment.new(path, filename: "file.txt", content_type: "text/plain"))

    assert {:ok, body} = Message.prepare(email)
    entries = Map.new(body.attachments, &{&1.filename, &1})
    assert Base.decode64!(entries["résumé.pdf"].content) == <<0, 255, 13, 10>>
    assert not Map.has_key?(entries["résumé.pdf"], :content_id)
    assert entries["logo.png"].content_id == "logo@fixture"
    assert Base.decode64!(entries["file.txt"].content) == "local content"
  end

  test "rejects multiple reply-to and unsupported provider options without dropping values" do
    assert {:error, :unsupported_reply_to} =
             Message.prepare(%{
               mail()
               | reply_to: [{"", "one@example.test"}, {"", "two@example.test"}]
             })

    assert {:error, :unsupported_provider_options} =
             Message.prepare(mail() |> put_provider_option(:template_id, "private-template"))
  end

  test "rejects structural, duplicate-case and injected headers" do
    for headers <- [
          %{"Bcc" => "private@example.test"},
          %{"Message-ID" => "<x@example.test>"},
          %{"DKIM-Signature" => "v=1"},
          %{"X-A" => "a", "x-a" => "b"},
          %{"X-Test" => "x\r\nBcc: private@example.test"}
        ] do
      assert {:error, :invalid_headers} = Message.prepare(%{mail() | headers: headers})
    end
  end

  test "no To recipient is rejected rather than promoting hidden recipients" do
    assert {:error, :invalid_recipients} =
             Message.prepare(%{mail() | to: [], bcc: [{"", "private@example.test"}]})
  end

  test "missing files return static errors without disclosing their path" do
    email =
      mail()
      |> attachment(%Swoosh.Attachment{
        path: "/secret-customer-file",
        filename: "x",
        content_type: "text/plain"
      })

    assert {:error, :attachment_unavailable} = Message.prepare(email)
  end

  test "invalid and duplicate inline content IDs are refused" do
    item =
      Swoosh.Attachment.new({:data, "x"},
        filename: "logo",
        content_type: "image/png",
        type: :inline,
        cid: "same"
      )

    assert {:error, :duplicate_content_id} =
             Message.prepare(%{mail() | attachments: [item, item]})

    assert {:error, :invalid_content_id} =
             Message.prepare(%{mail() | attachments: [%{item | cid: "not allowed"}]})
  end

  test "empty bodies, malformed structs and unsupported attachment metadata fail explicitly" do
    assert {:error, :missing_content} = Message.prepare(%{mail() | text_body: nil})
    assert {:error, :invalid_email} = Message.prepare(%{mail() | from: nil})

    item = %Swoosh.Attachment{
      filename: "x",
      content_type: "text/plain",
      data: "x",
      headers: [{"X-A", "b"}]
    }

    assert {:error, :unsupported_attachment_headers} =
             Message.prepare(%{mail() | attachments: [item]})
  end
end
