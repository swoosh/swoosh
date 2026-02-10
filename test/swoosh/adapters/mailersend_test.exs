defmodule Swoosh.Adapters.MailersendTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailersend

  setup do
    bypass = Bypass.open()
    config = [base_url: "http://localhost:#{bypass.port}", api_key: "test-api-key"]

    valid_email =
      new()
      |> from({"Tony Stark", "tony.stark@example.com"})
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("This is a test email.")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.request_path == "/v1/email"
      assert conn.method == "POST"

      assert conn.body_params["from"] == %{
               "email" => "tony.stark@example.com",
               "name" => "Tony Stark"
             }

      assert conn.body_params["to"] == [%{"email" => "steve.rogers@example.com"}]
      assert conn.body_params["subject"] == "Hello, Avengers!"
      assert conn.body_params["text"] == "This is a test email."

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-123")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-123"}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Avengers Update")
      |> html_body("<h1>Mission Report</h1><p>Status: Complete</p>")
      |> text_body("Mission Report\n\nStatus: Complete")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["html"] == "<h1>Mission Report</h1><p>Status: Complete</p>"
      assert conn.body_params["text"] == "Mission Report\n\nStatus: Complete"

      assert conn.body_params["to"] == [
               %{"email" => "steve.rogers@example.com", "name" => "Steve Rogers"}
             ]

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-456")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-456"}}
  end

  test "deliver/1 with multiple recipients returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to([{"Steve Rogers", "steve.rogers@example.com"}, "bruce.banner@example.com"])
      |> cc({"Natasha Romanoff", "natasha.romanoff@example.com"})
      |> bcc(["nick.fury@example.com", {"Maria Hill", "maria.hill@example.com"}])
      |> subject("Avengers Assemble")
      |> text_body("Important mission briefing.")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["to"] == [
               %{"email" => "steve.rogers@example.com", "name" => "Steve Rogers"},
               %{"email" => "bruce.banner@example.com"}
             ]

      assert conn.body_params["cc"] == [
               %{"email" => "natasha.romanoff@example.com", "name" => "Natasha Romanoff"}
             ]

      assert conn.body_params["bcc"] == [
               %{"email" => "nick.fury@example.com"},
               %{"email" => "maria.hill@example.com", "name" => "Maria Hill"}
             ]

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-789")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-789"}}
  end

  test "deliver/1 with reply-to returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> reply_to({"Stark Industries Support", "support@starkindustries.com"})
      |> subject("Technical Support")
      |> text_body("How can we help?")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["reply_to"] == %{
               "email" => "support@starkindustries.com",
               "name" => "Stark Industries Support"
             }

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-reply")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-reply"}}
  end

  test "deliver/1 with attachments returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Mission Briefing")
      |> html_body(~s(<p>Review briefing: <img src="cid:logo123"></p>))
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "fake pdf content"},
          filename: "mission-brief.pdf",
          content_type: "application/pdf"
        )
      )
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "fake image data"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo123"
        )
      )

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      [att1, att2] = conn.body_params["attachments"]

      # Regular attachment comes first (sorted)
      assert att1["filename"] == "mission-brief.pdf"
      assert att1["type"] == "application/pdf"
      assert att1["content"] == Base.encode64("fake pdf content")
      assert att1["disposition"] == "attachment"

      # Inline attachment
      assert att2["filename"] == "logo.png"
      assert att2["type"] == "image/png"
      assert att2["content"] == Base.encode64("fake image data")
      assert att2["disposition"] == "inline"
      assert att2["id"] == "logo123"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-att")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-att"}}
  end

  test "deliver/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Priority Message")
      |> text_body("Urgent update")
      |> header("X-Priority", "1")
      |> header("X-Custom-ID", "msg-12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      headers = conn.body_params["headers"]

      assert is_list(headers)
      assert %{"name" => "X-Priority", "value" => "1"} in headers
      assert %{"name" => "X-Custom-ID", "value" => "msg-12345"} in headers

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-headers")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-headers"}}
  end

  test "deliver/1 with template_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template_id, "welcome-template-123")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["template_id"] == "welcome-template-123"
      refute Map.has_key?(conn.body_params, "subject")
      refute Map.has_key?(conn.body_params, "text")
      refute Map.has_key?(conn.body_params, "html")

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-template")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-template"}}
  end

  test "deliver/1 with template variables returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to([{"Steve Rogers", "steve.rogers@example.com"}, "bruce.banner@example.com"])
      |> put_provider_option(:template_id, "mission-template-456")
      |> put_provider_option(:template_variables, %{
        "mission_name" => "Project Insight",
        "priority" => "High"
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["template_id"] == "mission-template-456"
      refute Map.has_key?(conn.body_params, "variables")

      assert length(conn.body_params["personalization"]) == 2
      [p1, p2] = conn.body_params["personalization"]
      assert p1["email"] == "steve.rogers@example.com"
      assert p2["email"] == "bruce.banner@example.com"

      assert p1["data"] == %{
               "mission_name" => "Project Insight",
               "priority" => "High"
             }

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-vars")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-vars"}}
  end

  test "deliver/1 with template and subject override returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("URGENT: Mission Update")
      |> put_provider_option(:template_id, "template-789")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["template_id"] == "template-789"
      assert conn.body_params["subject"] == "URGENT: Mission Update"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-override")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-override"}}
  end

  test "deliver/1 with non-template personalization returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to([
        {"Steve Rogers", "steve.rogers@example.com"},
        {"Bruce Banner", "bruce.banner@example.com"}
      ])
      |> subject("Welcome {{ name }}!")
      |> html_body("<h1>Hello {{ name }}</h1>")
      |> put_provider_option(:personalization, [
        %{"email" => "steve.rogers@example.com", "data" => %{"name" => "Steve"}},
        %{"email" => "bruce.banner@example.com", "data" => %{"name" => "Bruce"}}
      ])

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      refute Map.has_key?(conn.body_params, "template_id")
      assert conn.body_params["subject"] == "Welcome {{ name }}!"
      assert conn.body_params["html"] == "<h1>Hello {{ name }}</h1>"

      [p1, p2] = conn.body_params["personalization"]
      assert p1 == %{"email" => "steve.rogers@example.com", "data" => %{"name" => "Steve"}}
      assert p2 == %{"email" => "bruce.banner@example.com", "data" => %{"name" => "Bruce"}}

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-personalization")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-personalization"}}
  end

  test "deliver/1 with tracking options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Tracking Test")
      |> text_body("Test tracking features")
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:track_clicks, false)
      |> put_provider_option(:track_content, true)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["settings"] == %{
               "track_opens" => true,
               "track_clicks" => false,
               "track_content" => true
             }

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-tracking")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-tracking"}}
  end

  test "deliver/1 with tags returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Tagged Message")
      |> text_body("Test message with tags")
      |> put_provider_option(:tags, ["important", "avengers", "mission"])

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["tags"] == ["important", "avengers", "mission"]

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-tags")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-tags"}}
  end

  test "deliver/1 with metadata returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test")
      |> text_body("Test")
      |> put_provider_option(:metadata, %{"user_id" => "12345", "campaign" => "welcome"})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["metadata"] == %{
               "user_id" => "12345",
               "campaign" => "welcome"
             }

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-metadata")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-metadata"}}
  end

  test "deliver/1 with webhook_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test")
      |> text_body("Test")
      |> put_provider_option(:webhook_id, "webhook-abc-123")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["webhook_id"] == "webhook-abc-123"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-webhook")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-webhook"}}
  end

  test "deliver/1 with scheduled send time returns :ok", %{bypass: bypass, config: config} do
    send_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Scheduled Message")
      |> text_body("This will be sent later")
      |> put_provider_option(:send_at, send_at)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["send_at"] == send_at

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-scheduled")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-scheduled"}}
  end

  test "deliver/1 with send_at as DateTime returns :ok", %{bypass: bypass, config: config} do
    future_time = DateTime.utc_now() |> DateTime.add(7200, :second)
    expected_unix = DateTime.to_unix(future_time)

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Scheduled")
      |> text_body("Test")
      |> put_provider_option(:send_at, future_time)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["send_at"] == expected_unix

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-datetime")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-datetime"}}
  end

  test "deliver/1 with in_reply_to returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Re: Mission Update")
      |> text_body("Got it.")
      |> put_provider_option(:in_reply_to, "original-msg-id@example.com")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["in_reply_to"] == "original-msg-id@example.com"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-in-reply-to")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-in-reply-to"}}
  end

  test "deliver/1 with references returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Re: Re: Mission Update")
      |> text_body("Thread continues.")
      |> put_provider_option(:references, [
        "msg-1@example.com",
        "msg-2@example.com"
      ])

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["references"] == [
               "msg-1@example.com",
               "msg-2@example.com"
             ]

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-references")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-references"}}
  end

  test "deliver/1 with precedence_bulk returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Newsletter")
      |> text_body("Bulk email")
      |> put_provider_option(:precedence_bulk, true)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["precedence_bulk"] == true

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-precedence")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-precedence"}}
  end

  test "deliver/1 with list_unsubscribe returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Newsletter")
      |> text_body("Unsubscribe test")
      |> put_provider_option(:list_unsubscribe, "https://example.com/unsubscribe")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["list_unsubscribe"] == "https://example.com/unsubscribe"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-unsubscribe")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-unsubscribe"}}
  end

  test "deliver/1 with correct request headers", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test")
      |> text_body("Test")

    Bypass.expect(bypass, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-api-key"]
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/json"]
      assert Plug.Conn.get_req_header(conn, "x-requested-with") == ["XMLHttpRequest"]

      [user_agent] = Plug.Conn.get_req_header(conn, "user-agent")
      assert user_agent =~ "swoosh/"

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-req-headers")
      |> Plug.Conn.resp(202, "{}")
    end)

    assert Mailersend.deliver(email, config) == {:ok, %{id: "test-req-headers"}}
  end

  test "deliver/1 with 202 response containing warnings", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      response_body =
        ~s({"warnings":[{"type":"SOME_WARNING","warning":"Recipient not verified","recipients":["steve.rogers@example.com"]}]})

      conn
      |> Plug.Conn.put_resp_header("x-message-id", "test-warn")
      |> Plug.Conn.resp(202, response_body)
    end)

    assert {:ok, %{id: "test-warn", warnings: [warning]}} = Mailersend.deliver(email, config)
    assert warning["type"] == "SOME_WARNING"
    assert warning["warning"] == "Recipient not verified"
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 422, ~s({"message":"Validation error","errors":{"to":["required"]}}))
    end)

    assert {:error,
            {422, %{"message" => "Validation error", "errors" => %{"to" => ["required"]}}}} =
             Mailersend.deliver(email, config)
  end

  test "deliver/1 with 401 response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"message":"Unauthenticated."}))
    end)

    assert {:error, {401, %{"message" => "Unauthenticated."}}} =
             Mailersend.deliver(email, config)
  end

  test "deliver/1 with 429 response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 429, ~s({"message":"Too many requests"}))
    end)

    assert {:error, {429, %{"message" => "Too many requests"}}} =
             Mailersend.deliver(email, config)
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, ~s({"message":"Internal server error"}))
    end)

    assert {:error, {500, %{"message" => "Internal server error"}}} =
             Mailersend.deliver(email, config)
  end

  test "deliver/1 with non-JSON error response", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    assert {:error, {500, "Internal Server Error"}} = Mailersend.deliver(email, config)
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert :ok = Mailersend.validate_config(config)
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      "expected [:api_key] to be set, got: []\n",
      fn ->
        Mailersend.validate_config([])
      end
    )
  end
end
