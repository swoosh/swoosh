defmodule Swoosh.Adapters.AzureCommunicationServicesTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.AzureCommunicationServices

  # A real base64-encoded 32-byte key for HMAC testing
  @access_key Base.encode64("01234567890123456789012345678901")

  @operation_location "/emails/operations/op-123?api-version=2025-09-01"
  @success_response ~s({"id":"op-123","status":"Running"})

  setup do
    bypass = Bypass.open()

    config_hmac = [
      endpoint: "http://localhost:#{bypass.port}",
      access_key: @access_key
    ]

    config_bearer = [
      endpoint: "http://localhost:#{bypass.port}",
      auth: "my-bearer-token"
    ]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok,
     bypass: bypass,
     config_hmac: config_hmac,
     config_bearer: config_bearer,
     valid_email: valid_email}
  end

  test "successful delivery with HMAC access key auth", %{
    bypass: bypass,
    config_hmac: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.request_path == "/emails:send"
      assert conn.query_string == "api-version=2025-09-01"
      assert conn.method == "POST"

      # Verify HMAC auth headers are present and correctly formatted
      headers = Map.new(conn.req_headers)
      assert Map.has_key?(headers, "x-ms-date")
      assert Map.has_key?(headers, "x-ms-content-sha256")
      assert headers["host"] == "localhost:#{bypass.port}"
      authorization = headers["authorization"]
      assert authorization =~ "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256"
      assert authorization =~ "&Signature="

      assert conn.body_params == %{
               "senderAddress" => "tony.stark@example.com",
               "content" => %{
                 "subject" => "Hello, Avengers!",
                 "plainText" => "Hello",
                 "html" => "<h1>Hello</h1>"
               },
               "recipients" => %{
                 "to" => [%{"address" => "steve.rogers@example.com"}]
               }
             }

      conn
      |> Plug.Conn.put_resp_header("operation-location", @operation_location)
      |> Plug.Conn.put_resp_header("retry-after", "42")
      |> Plug.Conn.resp(202, @success_response)
    end)

    assert AzureCommunicationServices.deliver(email, config) ==
             {:ok,
              %{
                id: "op-123",
                status: "Running",
                operation_location: @operation_location,
                retry_after: 42
              }}
  end

  test "successful delivery with Bearer token auth", %{
    bypass: bypass,
    config_bearer: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      headers = Map.new(conn.req_headers)
      assert headers["authorization"] == "Bearer my-bearer-token"

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert AzureCommunicationServices.deliver(email, config) ==
             {:ok, %{id: "op-123", status: "Running"}}
  end

  test "successful delivery with HMAC auth combines the endpoint and API path", %{
    bypass: bypass,
    valid_email: email
  } do
    config = [
      endpoint: "http://localhost:#{bypass.port}/custom-path",
      access_key: @access_key
    ]

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.request_path == "/custom-path/emails:send"
      assert conn.query_string == "api-version=2025-09-01"
      assert Map.new(conn.req_headers)["host"] == "localhost:#{bypass.port}"

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert AzureCommunicationServices.deliver(email, config) ==
             {:ok, %{id: "op-123", status: "Running"}}
  end

  test "Bearer token as 0-arity function", %{bypass: bypass, valid_email: email} do
    config = [
      endpoint: "http://localhost:#{bypass.port}",
      auth: fn -> "token-from-fn" end
    ]

    Bypass.expect(bypass, fn conn ->
      headers = Map.new(conn.req_headers)
      assert headers["authorization"] == "Bearer token-from-fn"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "Bearer token as {m, f, a} tuple", %{bypass: bypass, valid_email: email} do
    config = [
      endpoint: "http://localhost:#{bypass.port}",
      auth: {String, :upcase, ["token-from-mfa"]}
    ]

    Bypass.expect(bypass, fn conn ->
      headers = Map.new(conn.req_headers)
      assert headers["authorization"] == "Bearer TOKEN-FROM-MFA"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "invalid bearer auth type raises ArgumentError", %{bypass: bypass, valid_email: email} do
    config = [
      endpoint: "http://localhost:#{bypass.port}",
      auth: :invalid
    ]

    assert_raise ArgumentError,
                 ~r/expected :auth to be a string, a 0-arity function, or a \{mod, fun, args\} tuple/,
                 fn ->
                   AzureCommunicationServices.deliver(email, config)
                 end
  end

  test "from with display name", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from({"Tony Stark", "tony.stark@example.com"})
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      # senderAddress only uses the email address, display name is not sent
      assert conn.body_params["senderAddress"] == "tony.stark@example.com"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "to with display name", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["recipients"]["to"] == [
               %{"address" => "steve.rogers@example.com", "displayName" => "Steve Rogers"}
             ]

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "CC and BCC recipients", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> cc({"Bruce Banner", "hulk@example.com"})
      |> cc("thor@example.com")
      |> bcc("natasha@example.com")
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      recipients = conn.body_params["recipients"]

      assert recipients["to"] == [%{"address" => "steve.rogers@example.com"}]

      assert Enum.sort(recipients["cc"]) ==
               Enum.sort([
                 %{"address" => "hulk@example.com", "displayName" => "Bruce Banner"},
                 %{"address" => "thor@example.com"}
               ])

      assert recipients["bcc"] == [%{"address" => "natasha@example.com"}]

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "single reply_to", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> reply_to("noreply@example.com")
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      assert conn.body_params["replyTo"] == [%{"address" => "noreply@example.com"}]
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "reply_to list", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> reply_to(["noreply@example.com", {"Tony", "tony@example.com"}])
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["replyTo"] == [
               %{"address" => "noreply@example.com"},
               %{"address" => "tony@example.com", "displayName" => "Tony"}
             ]

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "html-only body", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      content = conn.body_params["content"]
      assert content["html"] == "<h1>Hello</h1>"
      refute Map.has_key?(content, "plainText")
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "text-only body", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      content = conn.body_params["content"]
      assert content["plainText"] == "Hello"
      refute Map.has_key?(content, "html")
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "regular attachment", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")
      |> attachment(
        Swoosh.Attachment.new({:data, "PDF content"},
          filename: "doc.pdf",
          content_type: "application/pdf"
        )
      )

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      [attachment] = conn.body_params["attachments"]
      assert attachment["name"] == "doc.pdf"
      assert attachment["contentType"] == "application/pdf"
      assert attachment["contentInBase64"] == Base.encode64("PDF content")
      refute Map.has_key?(attachment, "contentId")
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "inline attachment", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> html_body(~s(<img src="cid:logo.png"/>))
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "image-data"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline
        )
      )

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      [attachment] = conn.body_params["attachments"]
      assert attachment["name"] == "logo.png"
      assert attachment["contentType"] == "image/png"
      assert attachment["contentInBase64"] == Base.encode64("image-data")
      assert attachment["contentId"] == "logo.png"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "inline attachment with explicit cid", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> html_body(~s(<img src="cid:my-logo"/>))
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "image-data"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "my-logo"
        )
      )

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      [attachment] = conn.body_params["attachments"]
      assert attachment["contentId"] == "my-logo"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "custom email headers", %{bypass: bypass, config_hmac: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")
      |> header("X-Custom-Header", "custom-value")
      |> header("X-Another", "another-value")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert conn.body_params["headers"] == %{
               "X-Custom-Header" => "custom-value",
               "X-Another" => "another-value"
             }

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "provider option: user_engagement_tracking_disabled", %{
    bypass: bypass,
    config_hmac: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")
      |> put_provider_option(:user_engagement_tracking_disabled, true)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      assert conn.body_params["userEngagementTrackingDisabled"] == true
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "provider option: operation_id sent as request header", %{
    bypass: bypass,
    config_hmac: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")
      |> put_provider_option(:operation_id, "550e8400-e29b-41d4-a716-446655440000")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      headers = Map.new(conn.req_headers)
      assert headers["operation-id"] == "550e8400-e29b-41d4-a716-446655440000"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "provider option: client_request_id sent as request header", %{
    bypass: bypass,
    config_hmac: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello!")
      |> text_body("Hello")
      |> put_provider_option(:client_request_id, "request-123")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      headers = Map.new(conn.req_headers)
      assert headers["x-ms-client-request-id"] == "request-123"
      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert {:ok, _} = AzureCommunicationServices.deliver(email, config)
  end

  test "4xx error response returns {:error, {code, parsed_json}}", %{
    bypass: bypass,
    config_hmac: config,
    valid_email: email
  } do
    error_body = ~s({"error":{"code":"InvalidAddress","message":"Invalid sender address"}})

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 400, error_body)
    end)

    assert AzureCommunicationServices.deliver(email, config) ==
             {:error,
              {400,
               %{"error" => %{"code" => "InvalidAddress", "message" => "Invalid sender address"}}}}
  end

  test "5xx error response returns {:error, {code, body}}", %{
    bypass: bypass,
    config_hmac: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    assert AzureCommunicationServices.deliver(email, config) ==
             {:error, {500, "Internal Server Error"}}
  end

  test "validate_config/1 with valid HMAC config", %{config_hmac: config} do
    assert AzureCommunicationServices.validate_config(config) == :ok
  end

  test "validate_config/1 with valid bearer config", %{config_bearer: config} do
    assert AzureCommunicationServices.validate_config(config) == :ok
  end

  test "validate_config/1 with missing endpoint raises ArgumentError" do
    assert_raise ArgumentError,
                 ~r/expected \[:endpoint\] to be set/,
                 fn ->
                   AzureCommunicationServices.validate_config(access_key: @access_key)
                 end
  end

  test "deliver/2 with missing auth raises ArgumentError", %{
    bypass: bypass,
    valid_email: email
  } do
    config = [endpoint: "http://localhost:#{bypass.port}"]

    assert_raise ArgumentError,
                 ~r/expected exactly one of \[:access_key, :auth\] to be set/,
                 fn ->
                   AzureCommunicationServices.deliver(email, config)
                 end
  end

  test "deliver/2 with both auth options raises ArgumentError", %{
    bypass: bypass,
    valid_email: email
  } do
    config = [
      endpoint: "http://localhost:#{bypass.port}",
      access_key: @access_key,
      auth: "my-bearer-token"
    ]

    assert_raise ArgumentError,
                 ~r/expected exactly one of \[:access_key, :auth\] to be set/,
                 fn ->
                   AzureCommunicationServices.deliver(email, config)
                 end
  end
end
