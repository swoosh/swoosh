defmodule Swoosh.Adapters.SendgridTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Sendgrid

  setup do
    bypass = Bypass.open
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
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"email" => "tony.stark@example.com"},
                      "personalizations" => [%{"to" => [%{"email" => "steve.rogers@example.com"}]
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"email" => "tony.stark@example.com"},
                      "personalizations" => [%{"to" => [%{"email" => "steve.rogers@example.com"}]
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"email" => "tony.stark@example.com"},
                      "personalizations" => [%{"to" => [%{"email" => "steve.rogers@example.com"}]
                      }],
                      "content" => [%{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
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

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "reply_to" => %{"email" => "hulk.smash@example.com"},
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
                        "cc" => [%{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"}, %{"email" => "hulk.smash@example.com"}],
                        "bcc" => [%{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"}, %{"email" => "thor.odinson@example.com"}]
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
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
      |> put_provider_option(:custom_args, %{my_var: %{"my_message_id": 123}, my_other_var: %{"my_other_id": 1, "stuff": 2}})

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "reply_to" => %{"email" => "hulk.smash@example.com"},
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
                        "cc" => [%{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"}, %{"email" => "hulk.smash@example.com"}],
                        "bcc" => [%{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"}, %{"email" => "thor.odinson@example.com"}],
                        "custom_args" => %{"my_var" => %{"my_message_id" => 123}, "my_other_var" => %{"stuff" => 2, "my_other_id" => 1}}
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!",
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with template_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:template_id, "Welcome")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}]
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!",
                      "template_id" => "Welcome"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with substitutions returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:substitutions, %{"-name-" => "Steve Rogers"})

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
                        "substitutions" => %{"-name-" => "Steve Rogers"}
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
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

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!",
                      "headers" => %{
                        "In-Reply-To" => "<1234@example.com>",
                        "X-Accept-Language" => "en",
                        "X-Mailer" => "swoosh",
                      }
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end

    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end
    assert Sendgrid.deliver(email, config) == {:error, {500, ""}}
  end


  test "validate_config/1 with valid config", %{config: config} do
    assert Sendgrid.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Sendgrid.validate_config([])
    end
  end

  test "delivery/1 with catogories returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:categories, ["welcome"])

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
                      "categories" => ["welcome"],
                      "personalizations" => [%{
                        "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}]
                      }],
                      "content" => [%{"type" => "text/plain", "value" => "Hello"}, %{"type" => "text/html", "value" => "<h1>Hello</h1>"}],
                      "subject" => "Hello, Avengers!"
                    }
      assert body_params == conn.body_params
      assert "/mail/send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

end
