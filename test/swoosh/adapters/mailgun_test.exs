defmodule Swoosh.Adapters.MailgunTest do
  use AdapterCase, async: true

  alias Swoosh.Adapters.Mailgun

  @success_response """
    {
      "message": "Queued. Thank you.",
      "id": "<20111114174239.25659.5817@samples.mailgun.org>"
    }
  """

  setup_all do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "fake",
              domain: "avengers.com"]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "steve.rogers@example.com",
                      "from" => "tony.stark@example.com",
                      "html" => "<h1>Hello</h1>"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "wasp.avengers@example.com,Steve Rogers <steve.rogers@example.com>",
                      "bcc" => "beast.avengers@example.com,Clinton Francis Barton <hawk.eye@example.com>",
                      "cc" => "thor.odinson@example.com,Bruce Banner <hulk.smash@example.com>",
                      "h:Reply-To" => "office.avengers@example.com",
                      "from" => "T Stark <tony.stark@example.com>",
                      "text" => "Hello",
                      "html" => "<h1>Hello</h1>"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:custom_vars, %{my_var: %{"my_message_id": 123}, my_other_var: %{"my_other_id": 1, "stuff": 2}})

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "steve.rogers@example.com",
                      "from" => "tony.stark@example.com",
                      "html" => "<h1>Hello</h1>",
                      "v:my_var" => "{\"my_message_id\":123}",
                      "v:my_other_var" => "{\"stuff\":2,\"my_other_id\":1}"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "steve.rogers@example.com",
                      "from" => "tony.stark@example.com",
                      "html" => "<h1>Hello</h1>",
                      "h:In-Reply-To" => "<1234@example.com>",
                      "h:X-Accept-Language" => "en",
                      "h:X-Mailer" => "swoosh"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 401, "Forbidden")
    end

    assert {:error, %AdapterError{reason: :unauthorized, original: "Forbidden"}} = Mailgun.deliver(email, config)
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    error_message = "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}"
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, error_message)
    end

    assert {:error, %AdapterError{reason: :server_error, original: ^error_message}} = Mailgun.deliver(email, config)
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mailgun.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:domain, :api_key] to be set, got: []
    """, fn ->
      Mailgun.validate_config([])
    end
  end
end
