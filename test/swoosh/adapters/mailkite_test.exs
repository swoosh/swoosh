defmodule Swoosh.Adapters.MailKiteTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  import Plug.Conn, only: [get_req_header: 2]
  alias Swoosh.Adapters.MailKite

  @send_path "/v1/send"
  @message_id "msg_0f256de268de4c098e42403771deb3fa"
  @success_response ~s({"id": "#{@message_id}", "status": "sent"})

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "mk_live_test-key",
      base_url: "http://localhost:#{bypass.port}"
    ]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  defp make_response(conn, body \\ @success_response), do: Plug.Conn.resp(conn, 202, body)

  defp success_result, do: {:ok, %{id: @message_id, status: "sent"}}

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "html" => "<h1>Hello</h1>",
               "text" => "Hello"
             }

      assert get_req_header(conn, "authorization") == ["Bearer mk_live_test-key"]
      assert get_req_header(conn, "content-type") == ["application/json"]

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "html" => "<h1>Hello</h1>"
             }

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with recipient names returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to({"Bruce Banner", "hulk.smash@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "T Stark <tony.stark@example.com>",
               "to" => ["Steve Rogers <steve.rogers@example.com>"],
               "replyTo" => "Bruce Banner <hulk.smash@example.com>",
               "subject" => "Hello, Avengers!",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 quotes display names that are not plain atoms", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from({"Stark, Tony", "tony.stark@example.com"})
      |> to({~s(Steve "Cap" Rogers), "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{
               "from" => ~s("Stark, Tony" <tony.stark@example.com>),
               "to" => [~s("Steve \\"Cap\\" Rogers" <steve.rogers@example.com>)]
             } = conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with cc, bcc and multiple recipients returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> to({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{
               "to" => ["Bruce Banner <hulk.smash@example.com>", "steve.rogers@example.com"],
               "cc" => ["thor.odinson@example.com"],
               "bcc" => ["Henry McCoy <beast.avengers@example.com>"]
             } = conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with several reply_to addresses joins them", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> reply_to([{"Pepper Potts", "pepper@example.com"}, "happy@example.com"])
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{"replyTo" => "Pepper Potts <pepper@example.com>, happy@example.com"} =
               conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with custom headers", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> header("X-Entity-Ref-ID", "ord_8812")
      |> header("List-Unsubscribe", "<mailto:unsub@example.com>")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{
               "headers" => %{
                 "X-Entity-Ref-ID" => "ord_8812",
                 "List-Unsubscribe" => "<mailto:unsub@example.com>"
               }
             } = conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with an attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> attachment(
        Swoosh.Attachment.new({:data, "Test content"},
          filename: "test.txt",
          content_type: "text/plain"
        )
      )

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{
               "attachments" => [
                 %{
                   "filename" => "test.txt",
                   "contentType" => "text/plain",
                   "content" => "VGVzdCBjb250ZW50"
                 }
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with an inline attachment returns an error without a request", %{
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body(~s(<img src="cid:logo">))
      |> attachment(
        Swoosh.Attachment.new({:data, "Test content"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo"
        )
      )

    assert MailKite.deliver(email, config) == {:error, :inline_attachments_not_supported}
  end

  test "deliver/1 with provider options", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:metadata, %{order_id: "ord_8812", tenant: "acme"})
      |> put_provider_option(:in_reply_to, "<original@example.com>")
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:track_clicks, false)

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{
               "metadata" => %{"order_id" => "ord_8812", "tenant" => "acme"},
               "inReplyTo" => "<original@example.com>",
               "trackOpens" => true,
               "trackClicks" => false
             } = conn.body_params

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with a template", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template_id, "tpl_welcome")
      |> put_provider_option(:template_data, %{name: "Steve"})

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "templateId" => "tpl_welcome",
               "templateData" => %{"name" => "Steve"}
             }

      make_response(conn)
    end)

    assert MailKite.deliver(email, config) == success_result()
  end

  test "deliver/1 with a scheduled send", %{bypass: bypass, config: config, valid_email: email} do
    email = put_provider_option(email, :scheduled_at, "2030-01-01T00:00:00Z")

    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      conn = parse(conn)

      assert %{"scheduledAt" => "2030-01-01T00:00:00Z"} = conn.body_params

      make_response(
        conn,
        ~s({"id": "ssnd_01hz", "status": "scheduled", "scheduledAt": 1893456000000})
      )
    end)

    assert MailKite.deliver(email, config) == {:ok, %{id: "ssnd_01hz", status: "scheduled"}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s({"error": "from must be an address on a verified domain"})

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    assert MailKite.deliver(email, config) ==
             {:error, {400, %{"error" => "from must be an address on a verified domain"}}}
  end

  test "deliver/1 with 401 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s({"error": "invalid api key"})

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 401, error))

    assert MailKite.deliver(email, config) == {:error, {401, %{"error" => "invalid api key"}}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", @send_path, fn conn ->
      assert @send_path == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert MailKite.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert MailKite.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_key] to be set, got: []
      """,
      fn ->
        MailKite.validate_config([])
      end
    )
  end
end
