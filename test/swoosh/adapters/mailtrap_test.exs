defmodule Swoosh.Adapters.MailtrapTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailtrap

  @success_response """
    {
      "success": true,
      "message_ids": [
        "0c7fd939-02cf-11ed-88c2-0a58a9feac02"
      ]
    }
  """

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
        "from" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
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
        "from" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
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
        "from" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
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
        "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "headers" => %{"Reply-To" => "hulk.smash@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "cc" => [
          %{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"},
          %{"email" => "hulk.smash@example.com"}
        ],
        "bcc" => [
          %{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"},
          %{"email" => "thor.odinson@example.com"}
        ],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
  end

  test "deliver/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
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
      |> put_provider_option(:custom_variables, %{
        my_var: %{my_message_id: 123},
        my_other_var: %{my_other_id: 1, stuff: 2}
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "headers" => %{"Reply-To" => "hulk.smash@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "cc" => [
          %{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"},
          %{"email" => "hulk.smash@example.com"}
        ],
        "bcc" => [
          %{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"},
          %{"email" => "thor.odinson@example.com"}
        ],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "custom_variables" => %{
          "my_var" => %{"my_message_id" => 123},
          "my_other_var" => %{"stuff" => 2, "my_other_id" => 1}
        }
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
  end

  test "deliver/1 with category returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:category, "alert")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "category" => "alert"
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
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
        "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "headers" => %{
          "In-Reply-To" => "<1234@example.com>",
          "X-Accept-Language" => "en",
          "X-Mailer" => "swoosh"
        }
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
  end

  test "deliver/1 with reply_to and custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> reply_to("hulk.smash@example.com")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!",
        "headers" => %{
          "Reply-To" => "hulk.smash@example.com",
          "In-Reply-To" => "<1234@example.com>",
          "X-Accept-Language" => "en",
          "X-Mailer" => "swoosh"
        }
      }

      assert body_params == conn.body_params
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
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
        "from" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "subject" => "Hello, Avengers!",
        "attachments" => [
          %{
            "filename" => "attachment.txt",
            "content" => attachment_content,
            "type" => "text/plain",
            "disposition" => "attachment"
          }
        ]
      }

      assert body_params == conn.body_params
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
  end

  test "deliver/1 with sandbox config returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => %{"email" => "tony.stark@example.com"},
        "to" => [%{"email" => "steve.rogers@example.com"}],
        "text" => "Hello",
        "html" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "/api/send/11111" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailtrap.deliver(email, config ++ [{:sandbox_inbox_id, "11111"}]) ==
             {:ok, %{ids: ["0c7fd939-02cf-11ed-88c2-0a58a9feac02"]}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    errors = "{\"errors\": [\"bla bla\"],\"success\": false}"

    Bypass.expect(bypass, &Plug.Conn.resp(&1, 400, errors))

    response = {:error, {400, %{"errors" => ["bla bla"], "success" => false}}}

    assert Mailtrap.deliver(email, config) == response
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    errors = "{\"errors\": [\"bla bla\"],\"success\": false}"

    Bypass.expect(bypass, &Plug.Conn.resp(&1, 400, errors))

    response = {:error, {400, %{"errors" => ["bla bla"], "success" => false}}}

    assert Mailtrap.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      assert "/api/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Mailtrap.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mailtrap.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:api_key] to be set, got: []
                 """,
                 fn ->
                   Mailtrap.validate_config([])
                 end
  end
end
