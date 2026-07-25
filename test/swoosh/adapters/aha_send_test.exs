defmodule Swoosh.Adapters.AhaSendTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  import Plug.Conn, only: [get_req_header: 2]
  alias Swoosh.Adapters.AhaSend

  @account_id "8b0c4f5e-1234-4a2b-9c3d-000000000000"
  @example_message_id "<0192a1b2-c3d4-7e8f-a9b0-c1d2e3f4a5b6@example.com>"
  @messages_path "/v2/accounts/#{@account_id}/messages"
  @conversation_path "/v2/accounts/#{@account_id}/messages/conversation"

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "aha-sk-test-key",
      account_id: @account_id,
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

  defp make_response(conn, status \\ "queued") do
    Plug.Conn.resp(conn, 202, """
      {
        "object": "list",
        "data": [
          {
            "object": "message",
            "id": "#{@example_message_id}",
            "recipient": {"email": "steve.rogers@example.com"},
            "status": "#{status}",
            "error": null
          }
        ]
      }
    """)
  end

  defp recipient_response(conn, recipient) do
    Plug.Conn.resp(conn, 202, """
      {
        "object": "list",
        "data": [
          {
            "object": "message",
            "id": "<msg-#{recipient}@example.com>",
            "recipient": {"email": "#{recipient}"},
            "status": "queued",
            "error": null
          }
        ]
      }
    """)
  end

  defp success_result(status \\ "queued") do
    {:ok,
     %{
       id: @example_message_id,
       status: status,
       messages: [
         %{
           id: @example_message_id,
           status: status,
           recipient: "steve.rogers@example.com",
           error: nil
         }
       ]
     }}
  end

  test "successful delivery returns :ok", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "recipients" => [%{"email" => "steve.rogers@example.com"}],
               "subject" => "Hello, Avengers!",
               "html_content" => "<h1>Hello</h1>",
               "text_content" => "Hello"
             }

      assert get_req_header(conn, "authorization") == ["Bearer aha-sk-test-key"]

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "delivery with a scheduled status", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      make_response(conn, "scheduled")
    end)

    assert AhaSend.deliver(email, config) == success_result("scheduled")
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "recipients" => [%{"email" => "steve.rogers@example.com"}],
               "subject" => "Hello, Avengers!",
               "text_content" => "Hello"
             }

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "recipients" => [%{"email" => "steve.rogers@example.com"}],
               "subject" => "Hello, Avengers!",
               "html_content" => "<h1>Hello</h1>"
             }

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with recipient names returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to({"Bruce Banner", "hulk.smash@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com", "name" => "T Stark"},
               "recipients" => [
                 %{"email" => "steve.rogers@example.com", "name" => "Steve Rogers"}
               ],
               "reply_to" => %{"email" => "hulk.smash@example.com", "name" => "Bruce Banner"},
               "subject" => "Hello, Avengers!",
               "text_content" => "Hello"
             }

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with cc and bcc uses the conversation endpoint", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> cc("hulk.smash@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @conversation_path, fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com", "name" => "T Stark"},
               "to" => [%{"email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
               "cc" => [%{"email" => "hulk.smash@example.com"}],
               "bcc" => [%{"email" => "beast.avengers@example.com", "name" => "Henry McCoy"}],
               "subject" => "Hello, Avengers!",
               "text_content" => "Hello"
             }

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with multiple recipients returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> to({"Bruce Banner", "hulk.smash@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{
               "recipients" => [
                 %{"email" => "hulk.smash@example.com", "name" => "Bruce Banner"},
                 %{"email" => "steve.rogers@example.com"}
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with custom headers", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> header("X-Custom-Header", "custom-value")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{"headers" => %{"X-Custom-Header" => "custom-value"}} = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with an attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> attachment(
        Swoosh.Attachment.new({:data, "Test content"},
          filename: "test.txt",
          content_type: "text/plain"
        )
      )

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{
               "attachments" => [
                 %{
                   "file_name" => "test.txt",
                   "content_type" => "text/plain",
                   "data" => "VGVzdCBjb250ZW50",
                   "base64" => true
                 }
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with an inline attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> attachment(
        Swoosh.Attachment.new({:data, "Test content"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo"
        )
      )

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{
               "attachments" => [
                 %{
                   "file_name" => "logo.png",
                   "content_id" => "logo",
                   "content_disposition" => "inline",
                   "base64" => true
                 }
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with provider options", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:tags, ["welcome", "onboarding"])
      |> put_provider_option(:tracking, %{open: true, click: false})
      |> put_provider_option(:sandbox, true)
      |> put_provider_option(:sandbox_result, "deliver")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{
               "tags" => ["welcome", "onboarding"],
               "tracking" => %{"open" => true, "click" => false},
               "sandbox" => true,
               "sandbox_result" => "deliver"
             } = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with substitutions and retention", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, {{ first_name }}!")
      |> text_body("Hello")
      |> put_provider_option(:substitutions, %{first_name: "Steve"})
      |> put_provider_option(:retention, %{metadata: 30, data: 7})

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{
               "substitutions" => %{"first_name" => "Steve"},
               "retention" => %{"metadata" => 30, "data" => 7}
             } = conn.body_params

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver/1 with a schedule", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:schedule, %{first_attempt: "2030-01-01T00:00:00Z"})

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert %{"schedule" => %{"first_attempt" => "2030-01-01T00:00:00Z"}} = conn.body_params

      make_response(conn, "scheduled")
    end)

    assert AhaSend.deliver(email, config) == success_result("scheduled")
  end

  test "deliver/1 with an idempotency key", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:idempotency_key, "unique-key-123")

    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)

      assert get_req_header(conn, "idempotency-key") == ["unique-key-123"]

      make_response(conn)
    end)

    assert AhaSend.deliver(email, config) == success_result()
  end

  test "deliver_many/2 with an empty list returns :ok", %{config: config} do
    assert AhaSend.deliver_many([], config) == {:ok, []}
  end

  test "deliver_many/2 sends each email in its own request", %{bypass: bypass, config: config} do
    emails =
      for recipient <- ["steve.rogers@example.com", "hulk.smash@example.com"] do
        new()
        |> from("tony.stark@example.com")
        |> to(recipient)
        |> subject("Hello, Avengers!")
        |> text_body("Hello")
      end

    test_pid = self()

    Bypass.expect(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)
      [%{"email" => recipient}] = conn.body_params["recipients"]
      send(test_pid, {:recipient, recipient})

      recipient_response(conn, recipient)
    end)

    {:ok, results} = AhaSend.deliver_many(emails, config)

    assert length(results) == 2
    assert_received {:recipient, "steve.rogers@example.com"}
    assert_received {:recipient, "hulk.smash@example.com"}
  end

  test "deliver_many/2 returns results in the order the emails were given", %{
    bypass: bypass,
    config: config
  } do
    emails =
      for recipient <- ["first@example.com", "second@example.com", "third@example.com"] do
        new()
        |> from("tony.stark@example.com")
        |> to(recipient)
        |> subject("Hello, Avengers!")
        |> text_body("Hello")
      end

    Bypass.expect(bypass, "POST", @messages_path, fn conn ->
      conn = parse(conn)
      [%{"email" => recipient}] = conn.body_params["recipients"]

      recipient_response(conn, recipient)
    end)

    {:ok, results} = AhaSend.deliver_many(emails, config)

    assert Enum.map(results, &(&1.messages |> hd() |> Map.get(:recipient))) ==
             ["first@example.com", "second@example.com", "third@example.com"]
  end

  test "deliver_many/2 delivers cc/bcc emails via the conversation endpoint", %{
    bypass: bypass,
    config: config
  } do
    emails = [
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> cc("hulk.smash@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello"),
      new()
      |> from("tony.stark@example.com")
      |> to("thor.odinson@example.com")
      |> cc("hulk.smash@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
    ]

    test_pid = self()

    Bypass.expect(bypass, "POST", @conversation_path, fn conn ->
      conn = parse(conn)
      send(test_pid, {:conversation, conn.body_params["to"]})

      make_response(conn)
    end)

    {:ok, results} = AhaSend.deliver_many(emails, config)

    assert length(results) == 2
    assert_received {:conversation, _}
    assert_received {:conversation, _}
  end

  test "deliver_many/2 stops at the first failure", %{bypass: bypass, config: config} do
    emails =
      for subject <- ["First", "Second"] do
        new()
        |> from("tony.stark@example.com")
        |> to("steve.rogers@example.com")
        |> subject(subject)
        |> text_body("Hello")
      end

    Bypass.expect(bypass, "POST", @messages_path, fn conn ->
      Plug.Conn.resp(conn, 422, ~s/{"message": "Validation failed"}/)
    end)

    assert AhaSend.deliver_many(emails, config) ==
             {:error, {422, %{"message" => "Validation failed"}}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"message": "Invalid request parameters"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    assert AhaSend.deliver(email, config) ==
             {:error, {400, %{"message" => "Invalid request parameters"}}}
  end

  test "deliver/1 with 401 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"message": "Unauthorized"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 401, error))

    assert AhaSend.deliver(email, config) == {:error, {401, %{"message" => "Unauthorized"}}}
  end

  test "deliver/1 with 422 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"message": "Validation failed", "errors": {"from": ["is required"]}}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 422, error))

    response =
      {:error,
       {422, %{"message" => "Validation failed", "errors" => %{"from" => ["is required"]}}}}

    assert AhaSend.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", @messages_path, fn conn ->
      assert @messages_path == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert AhaSend.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert AhaSend.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:account_id, :api_key] to be set, got: []
      """,
      fn ->
        AhaSend.validate_config([])
      end
    )
  end
end
