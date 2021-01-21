defmodule Plug.Swoosh.MailboxPreviewTest do
  use ExUnit.Case, async: true
  use Plug.Test

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
        |> put_provider_option(:template_model, %{name: "Steve", email: "steve@avengers.com"})
        |> attachment(
          Swoosh.Attachment.new("/data/file.png",
            headers: [{"Content-Type", "text/calendar; method=\"REQUEST\""}]
          )
        )
        |> Swoosh.Email.put_private(:sent_at, "2021-01-21T18:34:20.615851Z"),
        %Swoosh.Email{}
      ]
    end
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
                   "headers" => %{"X-Magic-Number" => "7"},
                   "provider_options" => [
                     %{
                       "key" => "template_model",
                       "value" => "%{email: \"steve@avengers.com\", name: \"Steve\"}"
                     }
                   ],
                   "attachments" => [
                     %{
                       "content_type" => "image/png",
                       "filename" => "file.png",
                       "headers" => %{"Content-Type" => "text/calendar; method=\"REQUEST\""},
                       "path" => "/data/file.png",
                       "type" => "attachment"
                     }
                   ]
                 },
                 %{
                   "bcc" => [],
                   "cc" => [],
                   "from" => "",
                   "reply_to" => "",
                   "sent_at" => nil,
                   "subject" => "",
                   "to" => [],
                   "html_body" => nil,
                   "text_body" => nil,
                   "headers" => %{},
                   "provider_options" => [],
                   "attachments" => []
                 }
               ]
             }
    end
  end
end
