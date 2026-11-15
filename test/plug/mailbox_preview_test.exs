defmodule Plug.Swoosh.MailboxPreviewTest do
  use ExUnit.Case, async: true

  import Plug.{Conn, Test}

  alias Plug.Swoosh.MailboxPreview

  defmodule StorageDriver do
    import Swoosh.Email

    def all do
      [
        new()
        |> subject("Peace, love, not war")
        |> from({"Admin", "admin@avengers.org"})
        |> reply_to("maria.hill@avengers.org")
        |> to("random@villain.me")
        |> cc("ironman@avengers.org")
        |> cc({"Thor", "thor@avengers.org"})
        |> bcc({nil, "thanos@villain.me"})
        |> bcc({"Bob", "hahaha@minions.org"})
        |> text_body("Lorem ipsum dolor sit amet")
        |> html_body("<p>Lorem ipsum dolor sit amet</p>")
        |> header("X-Magic-Number", "7")
        |> header("Message-ID", "1")
        |> put_provider_option(:template_model, template_model())
        |> attachment(
          Swoosh.Attachment.new({:data, "data"},
            filename: "file.png",
            content_type: "image/png"
          )
        )
        |> Swoosh.Email.put_private(:sent_at, "2021-01-21T18:34:20.615851Z"),
        new()
        |> subject("Avengers Assemble! 🦸‍♂️")
        |> from("TEMPLATE")
        |> to("avengers@shield.gov")
        |> text_body("Lorem ipsum dolor sit amet")
        |> html_body("<p>Lorem ipsum dolor sit amet</p>")
        |> header("Message-ID", "2")
      ]
    end

    def get(id) do
      emails = all()

      Enum.find(emails, fn %{headers: %{"Message-ID" => msg_id}} ->
        msg_id == String.downcase(id)
      end)
    end

    def template_model do
      %{name: "Steve", email: "steve@avengers.com"}
    end
  end

  defmodule BodyDriver do
    import Swoosh.Email

    def get("fragment"), do: email("<p>hi</p>")

    def get("doc"),
      do: email("<!DOCTYPE html><html><head><title>t</title></head><body>hi</body></html>")

    def get("upper"),
      do: email("<!DOCTYPE html><HTML><HEAD lang=\"en\"></HEAD><body>hi</body></HTML>")

    def get("nohead"), do: email("<!DOCTYPE html><html lang=\"en\"><body>hi</body></html>")
    def get("text"), do: new() |> text_body("plain <b>text</b>")

    defp email(html), do: new() |> html_body(html)
  end

  defmodule EmptyDriver do
    def all, do: []
    def get(_id), do: nil
    def template_model, do: %{}
  end

  defmodule XssDriver do
    import Swoosh.Email

    def email do
      new()
      |> subject("SUBJ<script>alert(1)</script>")
      |> from({"Admin", "admin@example.com"})
      |> to("victim@example.com")
      |> text_body("TXT<img src=x onerror=alert(1)>")
      |> html_body("<p>ok</p>")
      |> header("Message-ID", ~s|MID" onfocus="alert(1)|)
      |> header("X-Custom-Header", "HDRVAL<b>tag</b>")
      |> header("X-<raw-name>", "hv")
      |> put_provider_option(:template_model, "POV<script>alert(1)</script>")
      |> attachment(
        Swoosh.Attachment.new({:data, "data"},
          filename: "FNAME<script>alert(1)</script>.png",
          content_type: "image/png"
        )
      )
      |> Swoosh.Email.put_private(:sent_at, "2026-04-19T00:00:00Z")
    end

    def all, do: [email()]
    def get(_id), do: email()
  end

  defmodule NilFilenameDriver do
    import Swoosh.Email

    def email do
      new()
      |> from("admin@example.com")
      |> to("victim@example.com")
      |> header("Message-ID", "nil-fn")
      |> attachment(Swoosh.Attachment.new({:data, "data"}, content_type: "image/png"))
    end

    def all, do: [email()]
    def get(_id), do: email()
  end

  describe "/json" do
    test "renders emails in json" do
      opts = MailboxPreview.init(storage_driver: StorageDriver)

      conn = conn(:get, "/json")
      conn = MailboxPreview.call(conn, opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      json_response = Swoosh.json_library().decode!(conn.resp_body)

      assert json_response == %{
               "data" => [
                 %{
                   "bcc" => ["\"Bob\" <hahaha@minions.org>", "thanos@villain.me"],
                   "cc" => ["\"Thor\" <thor@avengers.org>", "ironman@avengers.org"],
                   "from" => "\"Admin\" <admin@avengers.org>",
                   "reply_to" => "maria.hill@avengers.org",
                   "sent_at" => "2021-01-21T18:34:20.615851Z",
                   "subject" => "Peace, love, not war",
                   "to" => ["random@villain.me"],
                   "html_body" => "<p>Lorem ipsum dolor sit amet</p>",
                   "text_body" => "Lorem ipsum dolor sit amet",
                   "headers" => %{
                     "X-Magic-Number" => "7",
                     "Message-ID" => "1"
                   },
                   "provider_options" => [
                     %{
                       "key" => "template_model",
                       "value" => inspect(StorageDriver.template_model())
                     }
                   ],
                   "attachments" => [
                     %{
                       "content_type" => "image/png",
                       "filename" => "file.png",
                       "headers" => %{},
                       "path" => nil,
                       "type" => "attachment"
                     }
                   ]
                 },
                 %{
                   "bcc" => [],
                   "cc" => [],
                   "from" => "TEMPLATE",
                   "reply_to" => "",
                   "sent_at" => nil,
                   "subject" => "Avengers Assemble! 🦸‍♂️",
                   "to" => ["avengers@shield.gov"],
                   "html_body" => "<p>Lorem ipsum dolor sit amet</p>",
                   "text_body" => "Lorem ipsum dolor sit amet",
                   "headers" => %{
                     "Message-ID" => "2"
                   },
                   "provider_options" => [],
                   "attachments" => []
                 }
               ]
             }
    end
  end

  describe "/" do
    test "with existing messages redirects to most recent" do
      opts = MailboxPreview.init(storage_driver: StorageDriver)

      conn = conn(:get, "/")
      conn = MailboxPreview.call(conn, opts)

      assert conn.state == :sent
      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["/1"]
    end

    test "with no messages redirects to base path" do
      opts = MailboxPreview.init(storage_driver: EmptyDriver)
      conn = conn(:get, "/")
      conn = MailboxPreview.call(conn, opts)
      assert get_resp_header(conn, "location") == []
    end
  end

  describe "/:id" do
    test "renders email details" do
      opts = MailboxPreview.init(storage_driver: StorageDriver)

      conn = conn(:get, "/3")
      conn = MailboxPreview.call(conn, opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      assert conn.resp_body =~ "Avengers Assemble! 🦸‍♂️"
    end
  end

  describe "/:id/html" do
    defp html_body(id) do
      opts = MailboxPreview.init(storage_driver: BodyDriver)
      conn = conn(:get, "/#{id}/html") |> MailboxPreview.call(opts)
      assert conn.status == 200
      conn.resp_body
    end

    test "adds base target to the head so links open outside the iframe" do
      assert html_body("doc") ==
               "<!DOCTYPE html><html><head><base target=\"_top\"><title>t</title></head><body>hi</body></html>"
    end

    test "matches the head tag case-insensitively and with attributes" do
      assert html_body("upper") =~ ~s(<HEAD lang="en"><base target="_top"></HEAD>)
    end

    test "adds a head when there is none" do
      assert html_body("nohead") =~
               ~s(<!DOCTYPE html><html lang="en"><head><base target="_top"></head><body>)
    end

    test "prepends the tag to a bare fragment" do
      assert html_body("fragment") == ~s(<base target="_top"><p>hi</p>)
    end

    test "leaves text-only emails untouched" do
      assert html_body("text") == "plain <b>text</b>"
    end
  end

  describe "HTML escaping in mailbox viewer" do
    setup do
      opts = MailboxPreview.init(storage_driver: XssDriver)
      conn = conn(:get, "/any-id") |> MailboxPreview.call(opts)
      {:ok, body: conn.resp_body}
    end

    test "escapes subject in the sidebar and detail view", %{body: body} do
      refute body =~ "SUBJ<script>alert(1)</script>"
      assert body =~ "SUBJ&lt;script&gt;alert(1)&lt;/script&gt;"
    end

    test "escapes text body", %{body: body} do
      refute body =~ "TXT<img src=x onerror=alert(1)>"
      assert body =~ "TXT&lt;img src=x onerror=alert(1)&gt;"
    end

    test "escapes arbitrary header values", %{body: body} do
      refute body =~ "HDRVAL<b>tag</b>"
      assert body =~ "HDRVAL&lt;b&gt;tag&lt;/b&gt;"
    end

    test "escapes arbitrary header names", %{body: body} do
      refute body =~ "X-<raw-name>"
      assert body =~ "X-&lt;raw-name&gt;"
    end

    test "escapes Message-ID when interpolated into href/src attributes", %{body: body} do
      refute body =~ ~s|onfocus="alert(1)"|
    end

    test "escapes provider_options values rendered via inspect/1", %{body: body} do
      refute body =~ "POV<script>alert(1)</script>"
      assert body =~ "POV&lt;script&gt;alert(1)&lt;/script&gt;"
    end

    test "escapes attachment filenames", %{body: body} do
      refute body =~ "FNAME<script>alert(1)</script>.png"
      assert body =~ "FNAME&lt;script&gt;alert(1)&lt;/script&gt;.png"
    end
  end

  describe "/:id/attachments/:index" do
    test "download attachment" do
      opts = MailboxPreview.init(storage_driver: StorageDriver)

      conn = conn(:get, "/1/attachments/0")
      conn = MailboxPreview.call(conn, opts)

      assert conn.state == :sent
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename*=UTF-8''file.png"
             ]
    end

    test "percent-encodes content-disposition for filenames with unsafe characters" do
      opts = MailboxPreview.init(storage_driver: XssDriver)

      conn = conn(:get, "/any/attachments/0")
      conn = MailboxPreview.call(conn, opts)

      [header] = get_resp_header(conn, "content-disposition")
      refute header =~ "<"
      refute header =~ ~s|"|

      assert header ==
               "attachment; filename*=UTF-8''FNAME%3Cscript%3Ealert%281%29%3C%2Fscript%3E.png"
    end

    test "falls back to a default content-disposition filename when nil" do
      opts = MailboxPreview.init(storage_driver: NilFilenameDriver)

      conn = conn(:get, "/nil-fn/attachments/0")
      conn = MailboxPreview.call(conn, opts)

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename*=UTF-8''attachment"
             ]
    end
  end
end
