defmodule Swoosh.Adapters.LettermintTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  import Plug.Conn, only: [get_req_header: 2]
  alias Swoosh.Adapters.Lettermint

  @example_message_id "msg_12345678-abcd-efgh-ijkl-123456789012"

  setup do
    bypass = Bypass.open()

    config = [
      api_token: "lm_test_token_123",
      base_url: "http://localhost:#{bypass.port}/v1"
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

  defp make_response(conn, status \\ "pending") do
    conn
    |> Plug.Conn.resp(202, """
        {
          "message_id": "#{@example_message_id}",
          "status": "#{status}"
        }
    """)
  end

  test "successful delivery returns :ok with status", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "html" => "<h1>Hello</h1>",
               "text" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      assert get_req_header(conn, "x-lettermint-token") == ["lm_test_token_123"]

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "delivery with different status values", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      make_response(conn, "queued")
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "queued"}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "text" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "html" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to("hulk.smash@example.com")
      |> cc("hulk.smash@example.com")
      |> cc({"Janet Pym", "wasp.avengers@example.com"})
      |> bcc("thor.odinson@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "T Stark <tony.stark@example.com>",
               "to" => ["Steve Rogers <steve.rogers@example.com>"],
               "reply_to" => ["hulk.smash@example.com"],
               "cc" => [
                 "Janet Pym <wasp.avengers@example.com>",
                 "hulk.smash@example.com"
               ],
               "bcc" => [
                 "Henry McCoy <beast.avengers@example.com>",
                 "thor.odinson@example.com"
               ],
               "text" => "Hello",
               "html" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with metadata returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:metadata, %{campaign: "welcome", user_id: "123"})

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert %{
               "from" => "T Stark <tony.stark@example.com>",
               "to" => ["Steve Rogers <steve.rogers@example.com>"],
               "subject" => "Hello, Avengers!",
               "metadata" => %{"campaign" => "welcome", "user_id" => "123"}
             } = conn.body_params

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with idempotency key", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:idempotency_key, "unique-key-123")

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert get_req_header(conn, "x-lettermint-token") == ["lm_test_token_123"]
      assert get_req_header(conn, "idempotency-key") == ["unique-key-123"]

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with custom headers", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> header("X-Custom-Header", "custom-value")
      |> header("X-Another-Header", "another-value")

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert %{
               "headers" => %{
                 "X-Custom-Header" => "custom-value",
                 "X-Another-Header" => "another-value"
               }
             } = conn.body_params

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with attachments", %{bypass: bypass, config: config} do
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

    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      conn = parse(conn)

      assert %{
               "attachments" => [
                 %{
                   "filename" => "test.txt",
                   "content" => "VGVzdCBjb250ZW50"
                 }
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert Lettermint.deliver(email, config) ==
             {:ok, %{id: @example_message_id, status: "pending"}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"error": "Invalid request parameters"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    response =
      {:error, {400, %{"error" => "Invalid request parameters"}}}

    assert Lettermint.deliver(email, config) == response
  end

  test "deliver/1 with 422 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"message": "Validation failed", "errors": {"from": ["is required"]}}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 422, error))

    response =
      {:error,
       {422,
        %{
          "message" => "Validation failed",
          "errors" => %{"from" => ["is required"]}
        }}}

    assert Lettermint.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v1/send", fn conn ->
      assert "/v1/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Lettermint.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Lettermint.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_token] to be set, got: []
      """,
      fn ->
        Lettermint.validate_config([])
      end
    )
  end
end
