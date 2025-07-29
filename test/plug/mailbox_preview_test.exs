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

  defmodule EmptyDriver do
    def all, do: []
    def get(_id), do: nil
    def template_model, do: %{}
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

  describe "/:id/attachments/:index" do
    test "download attachment" do
      opts = MailboxPreview.init(storage_driver: StorageDriver)

      conn = conn(:get, "/1/attachments/0")
      conn = MailboxPreview.call(conn, opts)

      assert conn.state == :sent
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"file.png\""
             ]
    end
  end
end
