defmodule Swoosh.Adapters.MailpitTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailpit

  @success_response ~s({"ID": "iAfZVVe2UQfNSG5BAjgYwa"})

  setup do
    bypass = Bypass.open()
    config = [base_url: "http://localhost:#{bypass.port}"]

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
        "From" => %{"Email" => "tony.stark@example.com"},
        "To" => [%{"Email" => "steve.rogers@example.com"}],
        "Text" => "Hello",
        "HTML" => "<h1>Hello</h1>",
        "Subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
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
        "From" => %{"Email" => "tony.stark@example.com"},
        "To" => [%{"Email" => "steve.rogers@example.com"}],
        "Text" => "Hello",
        "Subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
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
        "From" => %{"Email" => "tony.stark@example.com"},
        "To" => [%{"Email" => "steve.rogers@example.com"}],
        "HTML" => "<h1>Hello</h1>",
        "Subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
  end

  test "deliver with all fields returns :ok", %{bypass: bypass, config: config} do
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
        "From" => %{"Name" => "T Stark", "Email" => "tony.stark@example.com"},
        "To" => [%{"Name" => "Steve Rogers", "Email" => "steve.rogers@example.com"}],
        "ReplyTo" => [%{"Email" => "hulk.smash@example.com"}],
        "Cc" => [
          %{"Name" => "Janet Pym", "Email" => "wasp.avengers@example.com"},
          %{"Email" => "hulk.smash@example.com"}
        ],
        # Bcc order is newest-first (Swoosh prepends recipients to the list for efficiency)
        "Bcc" => ["beast.avengers@example.com", "thor.odinson@example.com"],
        "Text" => "Hello",
        "HTML" => "<h1>Hello</h1>",
        "Subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
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
        "From" => %{"Name" => "T Stark", "Email" => "tony.stark@example.com"},
        "To" => [%{"Name" => "Steve Rogers", "Email" => "steve.rogers@example.com"}],
        "Text" => "Hello",
        "HTML" => "<h1>Hello</h1>",
        "Subject" => "Hello, Avengers!",
        "Headers" => %{
          "In-Reply-To" => "<1234@example.com>",
          "X-Accept-Language" => "en",
          "X-Mailer" => "swoosh"
        }
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
  end

  test "deliver/1 with an attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> attachment("test/support/attachment.txt")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      attachment_content =
        "test/support/attachment.txt"
        |> File.read!()
        |> Base.encode64()

      body_params = %{
        "From" => %{"Email" => "tony.stark@example.com"},
        "To" => [%{"Email" => "steve.rogers@example.com"}],
        "Text" => "Hello",
        "Subject" => "Hello, Avengers!",
        "Attachments" => [
          %{
            "Filename" => "attachment.txt",
            "Content" => attachment_content,
            "ContentType" => "text/plain"
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailpit.deliver(email, config) ==
             {:ok, %{id: "iAfZVVe2UQfNSG5BAjgYwa"}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    errors = ~s({"error": "bad request"})

    Bypass.expect(bypass, &Plug.Conn.resp(&1, 400, errors))

    assert Mailpit.deliver(email, config) == {:error, {400, %{"error" => "bad request"}}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      assert "/api/v1/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Mailpit.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mailpit.validate_config(config) == :ok
  end
end
