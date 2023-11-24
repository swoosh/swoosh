defmodule Swoosh.Adapters.CustomerIOTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.CustomerIO

  setup do
    bypass = Bypass.open()
    config = [api_key: "123", base_url: "http://localhost:#{bypass.port}"]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => "steve.rogers@example.com",
        "subject" => "Hello, Avengers!",
        "body" => "<h1>Hello</h1>",
        "plaintext_body" => "Hello"
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => "steve.rogers@example.com",
        "plaintext_body" => "Hello",
        "subject" => "Hello, Avengers!"
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => "steve.rogers@example.com",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
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

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "reply_to" => "hulk.smash@example.com",
        "bcc" => ~s("Henry McCoy" <beast.avengers@example.com>, thor.odinson@example.com),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 with transactional_message_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:transactional_message_id, "Welcome")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "transactional_message_id" => "Welcome"
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 with message_data returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:message_data, %{name: "Steve Rogers"})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "message_data" => %{"name" => "Steve Rogers"}
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "headers" => [
          %{"In-Reply-To" => "<1234@example.com>"},
          %{"X-Accept-Language" => "en"},
          %{"X-Mailer" => "swoosh"}
        ]
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 with 429 response", %{bypass: bypass, config: config, valid_email: email} do
    errors = "{\"meta\": \"too many requests\"}"

    Bypass.expect(bypass, &Plug.Conn.resp(&1, 429, errors))

    response = {:error, {429, %{"meta" => "too many requests"}}}

    assert CustomerIO.deliver(email, config) == response
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    errors = "{\"meta\": \"error message explained\"}"

    Bypass.expect(bypass, &Plug.Conn.resp(&1, 400, errors))

    response = {:error, {400, %{"meta" => "error message explained"}}}

    assert CustomerIO.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert CustomerIO.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert CustomerIO.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:api_key] to be set, got: []
                 """,
                 fn ->
                   CustomerIO.validate_config([])
                 end
  end

  test "deliver/1 with queue_draft returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:queue_draft, true)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "queue_draft" => true
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 with tracked returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:tracked, false)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "plaintext_body" => "Hello",
        "body" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "tracked" => false
      }

      assert ^body_params = conn.body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 without subject", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => "steve.rogers@example.com",
        "body" => "<h1>Hello</h1>",
        "plaintext_body" => "Hello"
      }

      assert ^body_params = conn.body_params
      assert "subject" not in body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end

  test "deliver/1 without sender", %{bypass: bypass, config: config} do
    email =
      new()
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "to" => "steve.rogers@example.com",
        "subject" => "Hello, Avengers!",
        "body" => "<h1>Hello</h1>",
        "plaintext_body" => "Hello"
      }

      assert ^body_params = conn.body_params
      assert "from" not in body_params
      assert "/send/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "{\"delivery_id\": \"123-xyz\"}")
    end)

    assert CustomerIO.deliver(email, config) == {:ok, %{id: "123-xyz"}}
  end
end
