defmodule Swoosh.Adapters.SendinblueTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Sendinblue

  @example_message_id "<42.11@relay.example.com>"

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "123",
      base_url: "http://localhost:#{bypass.port}/v3"
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

  defp make_response(conn) do
    conn
    |> Plug.Conn.resp(200, "{\"messageId\": \"#{@example_message_id}\"}")
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
          "sender" => %{"email" => "tony.stark@example.com"},
          "to" => [%{"email" => "steve.rogers@example.com"}],
          "htmlContent" => "<h1>Hello</h1>",
          "textContent" => "Hello",
          "subject" => "Hello, Avengers!"
        }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
          "sender" => %{"email" => "tony.stark@example.com"},
          "to" => [%{"email" => "steve.rogers@example.com"}],
          "textContent" => "Hello",
          "subject" => "Hello, Avengers!"
        }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
        "sender" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "htmlContent" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
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

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
        "sender" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "replyTo" => %{"email" => "hulk.smash@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "cc" => [
          %{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"},
          %{"email" => "hulk.smash@example.com"}
        ],
        "bcc" => [
          %{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"},
          %{"email" => "thor.odinson@example.com"}
        ],
        "textContent" => "Hello",
        "htmlContent" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "delivery/1 with template_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_id, 42)

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
        "sender" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "subject" => "Hello, Avengers!",
        "templateId" => 42
      }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "delivery/1 with template_id and params returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
        |> from("tony.stark@example.com")
        |> to("steve.rogers@example.com")
        |> subject("Hello, Avengers!")
        |> text_body("Hello")
        |> put_provider_option(:template_id, 42)
        |> put_provider_option(:params, %{
          sample_template_param: "sample value",
          another_one: 99
        })

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
        "sender" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "textContent" => "Hello",
        "subject" => "Hello, Avengers!",
        "templateId" => 42,
        "params" => %{
          "sample_template_param" => "sample value",
          "another_one" => 99
        },
      }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "delivery/1 with template_id using template's from returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("TEMPLATE")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:template_id, "Welcome")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "textContent" => "Hello",
        "htmlContent" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "templateId" => "Welcome"
      }

      make_response(conn)
    end)

    assert Sendinblue.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "delivery/1 with 429 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"code": "too_many_requests", "message": "The expected rate limit is exceeded."}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 429, error))

    response =
      {:error, {429, %{
        "code" => "too_many_requests",
        "message" => "The expected rate limit is exceeded.",
      }}}

    assert Sendinblue.deliver(email, config) == response
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"code": "invalid_parameter", "message": "error message explained."}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    response =
        {:error, {400, %{
          "code" => "invalid_parameter",
          "message" => "error message explained.",
        }}}

    assert Sendinblue.deliver(email, config) == response
  end

  test "delivery/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      assert "/v3/smtp/email" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Sendinblue.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Sendinblue.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_key] to be set, got: []
      """,
      fn ->
        Sendinblue.validate_config([])
      end
    )
  end
end
