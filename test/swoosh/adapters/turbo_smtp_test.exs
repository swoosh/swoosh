defmodule Swoosh.Adapters.TurboSMTPTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  import Plug.Conn, only: [get_req_header: 2]
  alias Swoosh.Adapters.TurboSMTP
  alias Swoosh.Attachment

  # A real `mid` is a 64-bit snowflake.
  @example_mid 1_785_432_109_876_543_210

  setup do
    bypass = Bypass.open()

    config = [
      consumer_key: "test-consumer-key",
      consumer_secret: "test-consumer-secret",
      base_url: "http://localhost:#{bypass.port}/api/v2"
    ]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  defp make_response(conn) do
    Plug.Conn.resp(conn, 200, ~s|{"message": "OK", "mid": #{@example_mid}}|)
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => "steve.rogers@example.com",
               "subject" => "Hello, Avengers!",
               "content" => "Hello"
             }

      assert get_req_header(conn, "consumerkey") == ["test-consumer-key"]
      assert get_req_header(conn, "consumersecret") == ["test-consumer-secret"]

      make_response(conn)
    end)

    assert TurboSMTP.deliver(email, config) == {:ok, %{id: to_string(@example_mid)}}
  end

  test "the credentials never travel as an Authorization header", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      assert get_req_header(conn, "authorization") == []
      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to([{"Steve Rogers", "steve.rogers@example.com"}, "bruce.banner@example.com"])
      |> cc({"Bruce Banner", "hulk@example.com"})
      |> bcc("nick.fury@example.com")
      |> reply_to({"Pepper Potts", "pepper@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> html_body("<h1>Hello</h1>")
      |> header("X-Custom-Header", "custom")

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "T Stark <tony.stark@example.com>",
               "to" => "Steve Rogers <steve.rogers@example.com>,bruce.banner@example.com",
               "cc" => "Bruce Banner <hulk@example.com>",
               "bcc" => "nick.fury@example.com",
               "subject" => "Hello, Avengers!",
               "content" => "Hello",
               "html_content" => "<h1>Hello</h1>",
               "custom_headers" => %{
                 "X-Custom-Header" => "custom",
                 "Reply-To" => "Pepper Potts <pepper@example.com>"
               }
             }

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "multiple reply_to addresses are joined into a single header", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> reply_to([{"Pepper Potts", "pepper@example.com"}, "happy@example.com"])

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["custom_headers"] == %{
               "Reply-To" => "Pepper Potts <pepper@example.com>,happy@example.com"
             }

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "deliver/1 with provider options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:reference_id, "3a1f9d7e-0c4b-4f3a-9c1e-2b6d5a7f8e90")
      |> put_provider_option(:campaign_id, "welcome-2024")

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["reference_id"] == "3a1f9d7e-0c4b-4f3a-9c1e-2b6d5a7f8e90"
      assert conn.body_params["X-campaign-ID"] == "welcome-2024"

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "deliver/1 with an attachment returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> attachment(
        Attachment.new({:data, "hello"}, filename: "hello.txt", content_type: "text/plain")
      )

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["attachments"] == [
               %{
                 "name" => "hello.txt",
                 "type" => "text/plain",
                 "content" => Base.encode64("hello")
               }
             ]

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "an inline attachment keeps a bare content_id and qualifies the HTML reference", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body(~s|<img src="cid:logo.png"> and <img src="cid:logo.png.bak">|)
      |> attachment(
        Attachment.new({:data, "img"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline
        )
      )

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["attachments"] == [
               %{
                 "name" => "logo.png",
                 "type" => "image/png",
                 "content" => Base.encode64("img"),
                 "content_id" => "logo.png"
               }
             ]

      # The unrelated `logo.png.bak` reference must not be caught by the rewrite.
      assert conn.body_params["html_content"] ==
               ~s|<img src="cid:logo.png@example.com"> and <img src="cid:logo.png.bak">|

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "multiple inline attachments are all qualified", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body(~s|<img src="cid:logo.png"> and <img src="cid:banner.png">|)
      |> attachment(
        Attachment.new({:data, "img1"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline
        )
      )
      |> attachment(
        Attachment.new({:data, "img2"},
          filename: "banner.png",
          content_type: "image/png",
          type: :inline
        )
      )

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["html_content"] ==
               ~s|<img src="cid:logo.png@example.com"> and <img src="cid:banner.png@example.com">|

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "an inline content_id that already carries a domain is left alone", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body(~s|<img src="cid:logo@cdn.example.net">|)
      |> attachment(
        Attachment.new({:data, "img"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo@cdn.example.net"
        )
      )

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["html_content"] == ~s|<img src="cid:logo@cdn.example.net">|

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  # The API splits these fields on commas before it parses quoted display names.
  test "a comma in a recipient display name is rejected before sending", %{config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to({"Rogers, Steve", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    assert TurboSMTP.deliver(email, config) == {:error, {:invalid_recipient, "Rogers, Steve"}}
  end

  test "a comma in the sender display name is allowed", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"Stark, Tony", "tony.stark@example.com"})
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/api/v2/mail/send", fn conn ->
      conn = parse(conn)

      assert conn.body_params["from"] == "Stark, Tony <tony.stark@example.com>"

      make_response(conn)
    end)

    assert {:ok, _} = TurboSMTP.deliver(email, config)
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"message": "invalid request", "errors": ["missing recipients (to)"]}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    assert TurboSMTP.deliver(email, config) ==
             {:error,
              {400, %{"message" => "invalid request", "errors" => ["missing recipients (to)"]}}}
  end

  test "deliver/1 with 401 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"errorCode": 401, "message": "Wrong credentials"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 401, error))

    assert TurboSMTP.deliver(email, config) ==
             {:error, {401, %{"errorCode" => 401, "message" => "Wrong credentials"}}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 500, ""))

    assert TurboSMTP.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert TurboSMTP.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:consumer_secret, :consumer_key] to be set, got: []
      """,
      fn ->
        TurboSMTP.validate_config([])
      end
    )
  end
end
